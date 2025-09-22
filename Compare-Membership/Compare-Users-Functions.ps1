# Functions for Compare Users Demo (dot-source into main script)
# Expect the following variables to exist in scope from the main script:
#   $form, $dt [DataTable], $grid [DataGridView], $userColumns [List[string]], $defaultFont

function Add-UserColumn {
    param([string]$rawName, [switch]$Silent)

    $name = ($rawName -replace '[\r\n\t]+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show('Please enter a user/UPN to add.','Add User') | Out-Null }
        return $null
    }

    # Prevent duplicates (case-insensitive, ignoring trailing " (n)" suffix)
    $norm = [System.Text.RegularExpressions.Regex]::Replace($name, '\s*\(\d+\)$','').ToLowerInvariant()
    foreach ($uc in $userColumns) {
        $ucNorm = [System.Text.RegularExpressions.Regex]::Replace($uc, '\s*\(\d+\)$','').ToLowerInvariant()
        if ($ucNorm -eq $norm) {
            if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show("User already added:`n$($name)","Duplicate User") | Out-Null }
            return $null
        }
    }

    # Add data columns: current + hidden original
    $dc = New-Object System.Data.DataColumn($name, [bool]); $dc.DefaultValue = $false; [void]$dt.Columns.Add($dc)
    $dcOrig = New-Object System.Data.DataColumn("$name Original", [bool]); $dcOrig.DefaultValue = $false; [void]$dt.Columns.Add($dcOrig)

    foreach ($r in $dt.Rows) { $r[$name] = $false; $r["$name Original"] = $false }

    # Add grid column (checkbox). Header shows short name, but Name is full UPN.
    $col = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $col.HeaderText = ($name -replace '@.*$','')
    $col.DataPropertyName = $name
    $col.Name = $name
    $col.ThreeState = $false
    $col.ReadOnly = $false
    [void]$grid.Columns.Add($col)

    [void]$userColumns.Add($name)
    Update-ColumnOrder
    return $name
}

function Update-ColumnOrder {
    $i = 0
    foreach ($uc in $userColumns) {
        if ($grid.Columns.Contains($uc)) {
            $grid.Columns[$uc].DisplayIndex = 1 + $i
            $grid.Columns[$uc].ReadOnly = $false
            $i++
        }
    }
    if ($grid.Columns.Contains('Group'))       { $grid.Columns['Group'].DisplayIndex = 0;      $grid.Columns['Group'].ReadOnly = $true }
    if ($grid.Columns.Contains('Count'))       { $grid.Columns['Count'].DisplayIndex = 1 + $i; $grid.Columns['Count'].ReadOnly = $true }
    if ($grid.Columns.Contains('Description')) { $grid.Columns['Description'].DisplayIndex = 2 + $i; $grid.Columns['Description'].ReadOnly = $true }
    if ($grid.Columns.Contains('DN'))          { $grid.Columns['DN'].DisplayIndex = 3 + $i;    $grid.Columns['DN'].ReadOnly = $true }
}

function Remove-UserColumn { param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if ($grid.Columns.Contains($name)) { [void]$grid.Columns.Remove($name) }
    if ($dt.Columns.Contains($name))   {   $dt.Columns.Remove($name) }
    $orig = "$name Original"
    if ($dt.Columns.Contains($orig))   {   $dt.Columns.Remove($orig) }
    [void]$userColumns.Remove($name)
    Update-ColumnOrder
    Update-AllCounts
}

function Set-CellChangeStyle { param([int]$rowIndex, [string]$colName)
    try {
        if ($rowIndex -lt 0 -or -not $grid.Columns.Contains($colName)) { return }
        $rowView = $grid.Rows[$rowIndex].DataBoundItem
        if ($null -eq $rowView) { return }
        $row  = $rowView.Row
        $curr = [bool]$row[$colName]
        $orig = [bool]$row["$colName Original"]
        $cell = $grid.Rows[$rowIndex].Cells[$colName]
        if ($curr -ne $orig) {
            $cell.Style.BackColor = [System.Drawing.Color]::LightSalmon
            $cell.Style.SelectionBackColor = [System.Drawing.Color]::LightSalmon
            $cell.Style.SelectionForeColor = [System.Drawing.SystemColors]::ControlText
        } else {
            $cell.Style.BackColor = [System.Drawing.Color]::Empty
            $cell.Style.SelectionBackColor = [System.Drawing.Color]::Empty
            $cell.Style.SelectionForeColor = [System.Drawing.Color]::Empty
        }
        $grid.InvalidateCell($cell)
        $grid.Update()
    } catch {}
}

function Get-UserGroups { param([string]$UpnOrSam)
    $groups = @(); $found = $false
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null
            try {
                $u = Get-ADUser -Identity $UpnOrSam -Properties memberOf -ErrorAction Stop
            } catch {
                $u = Get-ADUser -Filter "userPrincipalName -eq '$UpnOrSam' -or sAMAccountName -eq '$UpnOrSam'" -Properties memberOf -ErrorAction Stop
            }
            if ($u) { $found = $true; if ($u.memberOf) { $groups = @($u.memberOf) } }
        }
    } catch {}
    if (-not $found) {
        try {
            $root = New-Object System.DirectoryServices.DirectoryEntry
            $searcher = New-Object System.DirectoryServices.DirectorySearcher($root)
            $searcher.Filter = "(&(objectClass=user)(|(userPrincipalName=$UpnOrSam)(sAMAccountName=$UpnOrSam)))"
            [void]$searcher.PropertiesToLoad.AddRange(@('distinguishedName','memberOf'))
            $res = $searcher.FindOne()
            if ($res) {
                $found = $true
                if ($res.Properties['memberOf']) { $groups = @($res.Properties['memberOf']) }
            }
        } catch {}
    }
    [pscustomobject]@{ Found = $found; Groups = $groups }
}

function Get-GroupInfoFromDN { param([string]$dn)
    $name = $null; $desc = $null; $resolvedDN = $dn
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            if (-not (Get-Module ActiveDirectory)) { Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null }
            try { $g = Get-ADGroup -Identity $dn -Properties description } catch {}
            if ($g) { $name = $g.Name; $desc = $g.Description; $resolvedDN = $g.DistinguishedName }
        }
    } catch {}
    if (-not $name) { if ($dn -match 'CN=([^,]+)') { $name = $matches[1] } else { $name = $dn } }
    [pscustomobject]@{ Name=$name; Description=$desc; DN=$resolvedDN }
}

function Ensure-GroupRow { param([string]$groupDN)
    foreach ($r in $dt.Rows) { if ([string]$r['DN'] -eq $groupDN) { return $r } }
    $info = Get-GroupInfoFromDN -dn $groupDN
    $nr = $dt.NewRow(); $nr['Group'] = $info.Name; $nr['Description'] = $info.Description; $nr['DN'] = $info.DN
    foreach ($uc in $userColumns) { $nr[$uc] = $false; $nr["$uc Original"] = $false }
    [void]$dt.Rows.Add($nr)
    Update-CountsForRow -row $nr
    return $nr
}

function Set-OriginalsForColumn { param([string]$colName) foreach ($r in $dt.Rows) { $r["$colName Original"] = [bool]$r[$colName] } }

function Update-CountsForRow { param([System.Data.DataRow]$row)
    if ($null -eq $row) { return }
    $count = 0; foreach ($uc in $userColumns) { try { if ([bool]$row[$uc]) { $count++ } } catch {} }
    if ($dt.Columns.Contains('Count')) { $row['Count'] = $count }
}

function Update-AllCounts { foreach ($r in $dt.Rows) { Update-CountsForRow -row $r } }

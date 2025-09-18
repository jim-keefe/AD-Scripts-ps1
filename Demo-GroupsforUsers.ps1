# --- Ensure STA & Windows PowerShell for WinForms ---
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA -or
    ($PSVersionTable.PSEdition -ne 'Desktop')) {
    $psExe = "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
    $args  = @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    Start-Process -FilePath $psExe -ArgumentList $args | Out-Null
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Compare Users Demo"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1100, 650)
$form.BackColor = [System.Drawing.Color]::Gainsboro  # light grey background

$defaultFont = $form.Font

# Title font for group boxes: bold, navy, +2pt (safe ctor)
$familyName = $defaultFont.FontFamily.Name
$newSizePt  = [single]([math]::Max(6, $defaultFont.SizeInPoints + 2))
try {
    $titleFont = New-Object System.Drawing.Font($familyName, $newSizePt, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
} catch {
    $titleFont = New-Object System.Drawing.Font($defaultFont, [System.Drawing.FontStyle]::Bold)
}

# Track dynamic user columns here
$userColumns = New-Object System.Collections.Generic.List[string]

# ---------- Root layout ----------
$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'
$root.ColumnCount = 1
$root.RowCount    = 3
$root.RowStyles.Clear()
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))         # top: single user box
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))     # middle: grid
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))         # bottom: button row
$form.Controls.Add($root)

# White border painter for group boxes (drawn around content, respecting caption gap)
$gbBorderPaint = {
    param($s, $e)
    try {
        $g = $e.Graphics
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White)
        try {
            $sz = [System.Windows.Forms.TextRenderer]::MeasureText($s.Text, $s.Font)
            $yTop = [int]([math]::Max(2, [math]::Round($sz.Height / 2.0)))
            $rect = $s.ClientRectangle
            $l = 1; $r = $rect.Width - 2; $b = $rect.Height - 2
            $gapL = 8
            $gapR = [math]::Min($r, $gapL + $sz.Width)
            if ($gapL -gt $l) { $g.DrawLine($pen, $l, $yTop, $gapL - 2, $yTop) }
            $g.DrawLine($pen, $gapR, $yTop, $r, $yTop)
            $g.DrawLine($pen, $l, $yTop, $l, $b)
            $g.DrawLine($pen, $r, $yTop, $r, $b)
            $g.DrawLine($pen, $l, $b, $r, $b)
        } finally { $pen.Dispose() }
    } catch {}
}

# ---------- Top: Two GroupBoxes (Add Users | Remove Users) ----------
$topRow = New-Object System.Windows.Forms.TableLayoutPanel
$topRow.Dock = 'Top'
$topRow.AutoSize = $true
$topRow.ColumnCount = 2
$topRow.RowCount = 1
$topRow.ColumnStyles.Clear()
[void]$topRow.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 70))  # Add Users stretches
[void]$topRow.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 30))       # Remove Users autosize
$root.Controls.Add($topRow, 0, 0)

# --- Left: Add Users ---
$gbAdd = New-Object System.Windows.Forms.GroupBox
$gbAdd.Text = 'Add Users for Review'
$gbAdd.Dock = 'Fill'
$gbAdd.AutoSize = $true
$gbAdd.Padding = [System.Windows.Forms.Padding]::new(15,15,15,15)
$gbAdd.Font = $titleFont
$gbAdd.ForeColor = [System.Drawing.Color]::MidnightBlue
$gbAdd.Margin = '0,3,0,0'
$topRow.Controls.Add($gbAdd); $topRow.SetColumn($gbAdd,0)
$gbAdd.add_Paint($gbBorderPaint)

$addInner = New-Object System.Windows.Forms.TableLayoutPanel
$addInner.Dock = 'Top'
$addInner.AutoSize = $true
$addInner.Font = $defaultFont
$addInner.ForeColor = [System.Drawing.SystemColors]::ControlText
$addInner.ColumnCount = 4
$addInner.RowCount = 1
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))    # UPN:
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100)) # textbox
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))    # Add User
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))    # Bulk Add

$gbAdd.Controls.Add($addInner)

$lblUpn = New-Object System.Windows.Forms.Label
$lblUpn.Text = 'UPN:'
$lblUpn.AutoSize = $true
$lblUpn.Margin = '3,6,3,3'
$lblUpn.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Width = 360
$txtUser.Anchor = 'Left,Right'

$btnAddUser = New-Object System.Windows.Forms.Button
$btnAddUser.Text = 'Add User'
$btnAddUser.AutoSize = $true

$btnBulkAdd = New-Object System.Windows.Forms.Button
$btnBulkAdd.Text = 'Bulk Add'
$btnBulkAdd.AutoSize = $true


[void]$addInner.Controls.Add($lblUpn, 0, 0)
[void]$addInner.Controls.Add($txtUser, 1, 0)
[void]$addInner.Controls.Add($btnAddUser, 2, 0)
[void]$addInner.Controls.Add($btnBulkAdd, 3, 0)


# --- Right: Remove Users ---
$gbRemove = New-Object System.Windows.Forms.GroupBox
$gbRemove.Text = 'Remove Users for Review'
$gbRemove.Dock = 'Top'
$gbRemove.AutoSize = $true
$gbRemove.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$gbRemove.MinimumSize = New-Object System.Drawing.Size(220,0)
$gbRemove.Margin = '8,3,0,0'
$gbRemove.Padding = [System.Windows.Forms.Padding]::new(15,15,15,15)
$gbRemove.Font = $titleFont
$gbRemove.ForeColor = [System.Drawing.Color]::MidnightBlue
$topRow.Controls.Add($gbRemove); $topRow.SetColumn($gbRemove,1)
$gbRemove.add_Paint($gbBorderPaint)

$remInner = New-Object System.Windows.Forms.FlowLayoutPanel
$remInner.Dock = 'Top'
$remInner.AutoSize = $true
$remInner.FlowDirection = 'LeftToRight'
$remInner.WrapContents = $false
$remInner.Font = $defaultFont
$remInner.ForeColor = [System.Drawing.SystemColors]::ControlText
$gbRemove.Controls.Add($remInner)

$btnRemoveSelect = New-Object System.Windows.Forms.Button
$btnRemoveSelect.Text = 'Select'
$btnRemoveSelect.AutoSize = $true

$btnRemoveAll = New-Object System.Windows.Forms.Button
$btnRemoveAll.Text  = 'All'
$btnRemoveAll.AutoSize = $true

[void]$remInner.Controls.Add($btnRemoveSelect)
[void]$remInner.Controls.Add($btnRemoveAll)

# ---------- Middle: GroupBox wrapping the grid ----------
$gbGrid = New-Object System.Windows.Forms.GroupBox
$gbGrid.Text = 'Group Comparison for Users'
$gbGrid.Dock = 'Fill'
$gbGrid.Padding = [System.Windows.Forms.Padding]::new(15,15,15,15)
$gbGrid.Font = $titleFont
$gbGrid.ForeColor = [System.Drawing.Color]::MidnightBlue
$root.Controls.Add($gbGrid, 0, 1)
$gbGrid.add_Paint($gbBorderPaint)

# Grid inside the group box
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false
$grid.AutoGenerateColumns = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.AutoSizeColumnsMode = 'Fill'
$grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
$grid.Font = $defaultFont
$grid.ForeColor = [System.Drawing.SystemColors]::ControlText
$grid.DefaultCellStyle.Font = $defaultFont
$grid.DefaultCellStyle.ForeColor = [System.Drawing.SystemColors]::ControlText
$gbGrid.Controls.Add($grid)

# ---------- Data model (no sample rows) & base columns ----------
$dt = New-Object System.Data.DataTable 'Demo'
[void]$dt.Columns.Add('Group',       [string])
[void]$dt.Columns.Add('Count',       [int])
[void]$dt.Columns.Add('Description', [string])
[void]$dt.Columns.Add('DN',          [string])

# Base grid columns
$colGroup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colGroup.HeaderText       = 'Group'
$colGroup.DataPropertyName = 'Group'
$colGroup.Name             = 'Group'

# Count column (computed number of checked user boxes)
$colCount = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colCount.HeaderText       = 'Count'
$colCount.DataPropertyName = 'Count'
$colCount.Name             = 'Count'
$colCount.ReadOnly         = $true
$colCount.AutoSizeMode     = 'AllCells'
$colCount.DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter

$colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colDesc.HeaderText        = 'Description'
$colDesc.DataPropertyName  = 'Description'
$colDesc.Name              = 'Description'

$colDN = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colDN.HeaderText          = 'DN'
$colDN.DataPropertyName    = 'DN'
$colDN.Name              = 'DN'

# Make base columns read-only; only user (checkbox) columns are editable
$colGroup.ReadOnly = $true
$colDesc.ReadOnly  = $true
$colDN.ReadOnly    = $true

[void]$grid.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($colGroup, $colCount, $colDesc, $colDN))
$grid.DataSource = $dt

# Zebra stripes after binding
$grid.RowsDefaultCellStyle.BackColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow  # light grey alt rows
# Row 'selection' colors disabled (match row backgrounds)
$grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.SystemColors]::ControlText
$grid.RowsDefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::LightYellow

# Header styling: MidnightBlue background, bold light-yellow text
$lightYellow = [System.Drawing.Color]::FromArgb(240,240,224)
$grid.EnableHeadersVisualStyles = $false
$hdr = New-Object System.Windows.Forms.DataGridViewCellStyle
$hdr.BackColor = [System.Drawing.Color]::MidnightBlue
$hdr.ForeColor = $lightYellow
$hdr.SelectionBackColor = $hdr.BackColor
$hdr.SelectionForeColor = $hdr.ForeColor
$hdr.Font = New-Object System.Drawing.Font($defaultFont, [System.Drawing.FontStyle]::Bold)
$hdr.Padding = New-Object System.Windows.Forms.Padding(8,4,8,4)
$grid.ColumnHeadersDefaultCellStyle = $hdr
$grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize

# Make the "Group" column cells bold (normal point size)
$boldGroupFont = New-Object System.Drawing.Font($defaultFont.FontFamily, [single]$defaultFont.SizeInPoints, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$colGroup.DefaultCellStyle.Font = $boldGroupFont

# ---------- Dynamic user column support ----------
function Add-UserColumn {
    param([string]$rawName, [switch]$Silent)

    $name = ($rawName -replace '[\r\n\t]+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        [System.Windows.Forms.MessageBox]::Show('Please enter a user/UPN to add.','Add User') | Out-Null
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
    $dc = New-Object System.Data.DataColumn($name, [bool])
    $dc.DefaultValue = $false
    [void]$dt.Columns.Add($dc)

    $dcOrig = New-Object System.Data.DataColumn("$name Original", [bool])
    $dcOrig.DefaultValue = $false
    [void]$dt.Columns.Add($dcOrig)

    # Initialize existing rows
    foreach ($r in $dt.Rows) { $r[$name] = $false; $r["$name Original"] = $false }

    # Add grid column
    $col = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $col.HeaderText = ($name -replace '@.*$','')  # show short name; keep full UPN internally
    $col.DataPropertyName = $name
    $col.Name = $name
    $col.ThreeState = $false
    $col.ReadOnly = $false
    [void]$grid.Columns.Add($col)

    # Track as a user column
    [void]$userColumns.Add($name)

    # Ensure user columns appear between Group and Description (in order)
    Update-ColumnOrder

    return $name
}

# Keep user columns between Group and Description and editable; base cols read-only
function Update-ColumnOrder {
    $i = 0
    foreach ($uc in $userColumns) {
        if ($grid.Columns.Contains($uc)) {
            $grid.Columns[$uc].DisplayIndex = 1 + $i
            $grid.Columns[$uc].ReadOnly = $false
            $i++
        }
    }
    if ($grid.Columns.Contains('Group'))       { $grid.Columns['Group'].DisplayIndex       = 0;         $grid.Columns['Group'].ReadOnly       = $true }
    if ($grid.Columns.Contains('Count'))       { $grid.Columns['Count'].DisplayIndex       = 1 + $i;    $grid.Columns['Count'].ReadOnly       = $true }
    if ($grid.Columns.Contains('Description')) { $grid.Columns['Description'].DisplayIndex = 2 + $i;    $grid.Columns['Description'].ReadOnly = $true }
    if ($grid.Columns.Contains('DN'))          { $grid.Columns['DN'].DisplayIndex          = 3 + $i;    $grid.Columns['DN'].ReadOnly          = $true }
}

# Remove a user column and its hidden original, then fix order and its hidden original, then fix order
function Remove-UserColumn {
    param([string]$name)
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if ($grid.Columns.Contains($name)) { [void]$grid.Columns.Remove($name) }
    if ($dt.Columns.Contains($name))   {   $dt.Columns.Remove($name) }
    $orig = "$name Original"
    if ($dt.Columns.Contains($orig))   {   $dt.Columns.Remove($orig) }
    [void]$userColumns.Remove($name)
    Update-ColumnOrder
    Update-AllCounts
}

# Directly set style for a single cell so highlight shows immediately
function Set-CellChangeStyle {
    param([int]$rowIndex, [string]$colName)
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

# --- Directory lookup helpers ---
function Get-UserGroups {
    param([string]$UpnOrSam)
    $groups = @()
    $found  = $false
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null
            try {
                $u = Get-ADUser -Identity $UpnOrSam -Properties memberOf -ErrorAction Stop
            } catch {
                $u = Get-ADUser -Filter "userPrincipalName -eq '$UpnOrSam' -or sAMAccountName -eq '$UpnOrSam'" -Properties memberOf -ErrorAction Stop
            }
            if ($u) {
                $found = $true
                if ($u.memberOf) { $groups = @($u.memberOf) }
            }
        }
    } catch {}
    if (-not $found) {
        try {
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
            $searcher.Filter = "(|(userPrincipalName=$UpnOrSam)(sAMAccountName=$UpnOrSam))"
            [void]$searcher.PropertiesToLoad.Add('memberOf')
            $res = $searcher.FindOne()
            if ($res) {
                $found = $true
                if ($res.Properties['memberOf']) { $groups = @($res.Properties['memberOf']) }
            }
        } catch {}
    }
    [pscustomobject]@{ Found = $found; Groups = $groups }
}

function Get-GroupInfoFromDN {
    param([string]$dn)
    $name = $null; $desc = $null; $resolvedDN = $dn
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            if (-not (Get-Module ActiveDirectory)) { Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null }
            try {
                $g = Get-ADGroup -Identity $dn -Properties description
                if ($g) {
                    $name = $g.Name
                    $desc = $g.Description
                    $resolvedDN = $g.DistinguishedName
                }
            } catch {}
        }
    } catch {}
    if (-not $name) {
        if ($dn -match 'CN=([^,]+)') { $name = $matches[1] } else { $name = $dn }
    }
    [pscustomobject]@{ Name=$name; Description=$desc; DN=$resolvedDN }
}

function Ensure-GroupRow {
    param([string]$groupDN)
    foreach ($r in $dt.Rows) { if ([string]$r['DN'] -eq $groupDN) { return $r } }
    $info = Get-GroupInfoFromDN -dn $groupDN
    $nr = $dt.NewRow()
    $nr['Group'] = $info.Name
    $nr['Description'] = $info.Description
    $nr['DN'] = $info.DN
    foreach ($uc in $userColumns) { $nr[$uc] = $false; $nr["$uc Original"] = $false }
    [void]$dt.Rows.Add($nr)
    Update-CountsForRow -row $nr
    return $nr
}

function Set-OriginalsForColumn {
    param([string]$colName)
    foreach ($r in $dt.Rows) { $r["$colName Original"] = [bool]$r[$colName] }
}

# Recalculate Count for one row / all rows
function Update-CountsForRow {
    param([System.Data.DataRow]$row)
    if ($null -eq $row) { return }
    $count = 0
    foreach ($uc in $userColumns) {
        try { if ([bool]$row[$uc]) { $count++ } } catch {}
    }
    if ($dt.Columns.Contains('Count')) { $row['Count'] = $count }
}
function Update-AllCounts {
    foreach ($r in $dt.Rows) { Update-CountsForRow -row $r }
}



# --- Instant repaint & live Count updates for checkbox edits ---
$grid.add_CurrentCellDirtyStateChanged({
    if ($grid.IsCurrentCellDirty) {
        $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        $grid.EndEdit()
        try {
            $cell = $grid.CurrentCell
            if ($cell -ne $null) {
                $col = $cell.OwningColumn
                $rowIndex = $cell.RowIndex
                if ($col -and ($col -is [System.Windows.Forms.DataGridViewCheckBoxColumn]) -and $userColumns.Contains($col.Name)) {
                    Set-CellChangeStyle -rowIndex $rowIndex -colName $col.Name
                    $rv = $grid.Rows[$rowIndex].DataBoundItem
                    if ($rv) { Update-CountsForRow -row $rv.Row }
                    if ($grid.Columns.Contains('Count')) { $grid.InvalidateCell($grid.Columns['Count'].Index, $rowIndex) }
                }
            }
        } catch {}
    }
})

$grid.add_CellValueChanged({
    param($s, $e)
    if ($e.RowIndex -ge 0) {
        try {
            $col = $grid.Columns[$e.ColumnIndex]
            if ($col -and ($col -is [System.Windows.Forms.DataGridViewCheckBoxColumn]) -and $userColumns.Contains($col.Name)) {
                Set-CellChangeStyle -rowIndex $e.RowIndex -colName $col.Name
                $rv = $grid.Rows[$e.RowIndex].DataBoundItem
                if ($rv) { Update-CountsForRow -row $rv.Row }
                if ($grid.Columns.Contains('Count')) { $grid.InvalidateCell($grid.Columns['Count'].Index, $e.RowIndex) }
            }
        } catch {}
    }
})

# Add User button
$btnAddUser.Add_Click({
    $upn = ($txtUser.Text).Trim()
    if ([string]::IsNullOrWhiteSpace($upn)) { return }

    # Prevent duplicates before any directory call
    $norm = [System.Text.RegularExpressions.Regex]::Replace($upn, '\s*\(\d+\)$','').ToLowerInvariant()
    foreach ($uc in $userColumns) {
        $ucNorm = [System.Text.RegularExpressions.Regex]::Replace($uc, '\s*\(\d+\)$','').ToLowerInvariant()
        if ($ucNorm -eq $norm) {
            [System.Windows.Forms.MessageBox]::Show("User already added:`n$upn","Duplicate User") | Out-Null
            return
        }
    }

    # Look up first; only add to grid if account exists
    $lookup = Get-UserGroups -UpnOrSam $upn
    if (-not $lookup.Found) {
        [System.Windows.Forms.MessageBox]::Show("User not found in Active Directory:`n$upn","User Not Found") | Out-Null
        return
    }

    $added = Add-UserColumn -rawName $upn -Silent
    if (-not $added) { return }
    if ($added) {
        $groups = @($lookup.Groups)
        if ($groups -and $groups.Count -gt 0) {
            foreach ($gdn in $groups) { try { $row = Ensure-GroupRow -groupDN ([string]$gdn); $row[$added] = $true } catch {} }
            foreach ($r in $dt.Rows) { if (-not ($groups -contains [string]$r['DN'])) { $r[$added] = $false } }
        }
        Set-OriginalsForColumn -colName $added
        $dt.DefaultView.Sort = 'Group ASC'
        Update-AllCounts
        $dt.AcceptChanges()
    }
    $txtUser.Clear(); $txtUser.Focus()
})
$txtUser.Add_KeyDown({ param($s,$e) if ($e.KeyCode -eq 'Enter') { $btnAddUser.PerformClick() } })

# Bulk Add Users dialog
$btnBulkAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Bulk Add Users'
    $dlg.StartPosition = 'CenterParent'
    $dlg.Size = New-Object System.Drawing.Size(560, 480)

    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = 'Fill'; $panel.ColumnCount = 1; $panel.RowCount = 3
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Enter one UPN per line:'
    $lbl.AutoSize = $true

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ScrollBars = 'Both'
    $tb.WordWrap = $false
    $tb.Dock = 'Fill'

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.AutoSize = $true
    $buttons.Dock = 'Top'

    $btnSubmit = New-Object System.Windows.Forms.Button
    $btnSubmit.Text = 'Submit'
    $btnSubmit.AutoSize = $true

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.AutoSize = $true

    [void]$buttons.Controls.Add($btnSubmit)
    [void]$buttons.Controls.Add($btnCancel)

    $panel.Controls.Add($lbl, 0, 0)
    $panel.Controls.Add($tb, 0, 1)
    $panel.Controls.Add($buttons, 0, 2)

    $dlg.Controls.Add($panel)

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnSubmit.Add_Click({
        $entries = @($tb.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($entries.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Please enter at least one UPN.','Bulk Add Users') | Out-Null
            return
        }
        $dlg.Tag = $entries
        $dlg.Close()
    })

    [void]$dlg.ShowDialog($form)

    $entries = $dlg.Tag
    if ($entries -and $entries.Count -gt 0) {
        $notFound  = New-Object System.Collections.Generic.List[string]
        $duplicates = New-Object System.Collections.Generic.List[string]
        foreach ($upn in $entries) {
            $lookup = Get-UserGroups -UpnOrSam $upn
            if (-not $lookup.Found) { [void]$notFound.Add($upn); continue }

            $added = Add-UserColumn -rawName $upn -Silent
            if (-not $added) { [void]$duplicates.Add($upn); continue }

            $groups = @($lookup.Groups)
            if ($groups -and $groups.Count -gt 0) {
                foreach ($gdn in $groups) { try { $row = Ensure-GroupRow -groupDN ([string]$gdn); $row[$added] = $true } catch {} }
                foreach ($r in $dt.Rows) { if (-not ($groups -contains [string]$r['DN'])) { $r[$added] = $false } }
            }
            Set-OriginalsForColumn -colName $added
        }
        $dt.DefaultView.Sort = 'Group ASC'
        Update-AllCounts
        $dt.AcceptChanges()
        if ($notFound.Count -gt 0 -or $duplicates.Count -gt 0) {
            $parts = @()
            if ($notFound.Count -gt 0)   { $parts += "Not found:`n" + ([string]::Join("`n", $notFound)) }
            if ($duplicates.Count -gt 0) { $parts += "Duplicates (skipped):`n" + ([string]::Join("`n", $duplicates)) }
            $msg = [string]::Join("`n`n", $parts)
            [System.Windows.Forms.MessageBox]::Show($msg,'Bulk Add Summary') | Out-Null
        }
    }
})

# ---------- Bottom: Actions group box ----------
$gbActions = New-Object System.Windows.Forms.GroupBox
$gbActions.Text = 'Actions'
$gbActions.Dock = 'Top'
$gbActions.AutoSize = $true
$gbActions.Padding = [System.Windows.Forms.Padding]::new(15,15,15,15)
$gbActions.Font = $titleFont
$gbActions.ForeColor = [System.Drawing.Color]::MidnightBlue
$root.Controls.Add($gbActions, 0, 2)
$gbActions.add_Paint($gbBorderPaint)

$actionsInner = New-Object System.Windows.Forms.FlowLayoutPanel
$actionsInner.FlowDirection = 'RightToLeft'
$actionsInner.AutoSize = $true
$actionsInner.Dock = 'Top'
$gbActions.Controls.Add($actionsInner)

$btnPerform = New-Object System.Windows.Forms.Button
$btnPerform.Text = 'Review Add/Remove'
$btnPerform.AutoSize = $true
[void]$actionsInner.Controls.Add($btnPerform)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = 'Export to CSV'
$btnExport.AutoSize = $true
[void]$actionsInner.Controls.Add($btnExport)

$btnCreds = New-Object System.Windows.Forms.Button
$btnCreds.Text = 'Add Credentials'
$btnCreds.AutoSize = $true
[void]$actionsInner.Controls.Add($btnCreds)

# Remove Users: All
$btnRemoveAll.Add_Click({
    if ($userColumns.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No user columns to remove.','Remove Users') | Out-Null
        return
    }
    $toRemove = @($userColumns.ToArray())
    foreach ($uc in $toRemove) { Remove-UserColumn -name $uc }
})

# Remove Users: Select
$btnRemoveSelect.Add_Click({
    if ($userColumns.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No user columns to select.','Remove Users') | Out-Null
        return
    }

    # Build selection table
    $udt = New-Object System.Data.DataTable 'UsersToRemove'
    [void]$udt.Columns.Add('User',[string])
    [void]$udt.Columns.Add('Remove',[bool])
    foreach ($u in $userColumns) { $row = $udt.NewRow(); $row['User'] = $u; $row['Remove'] = $false; [void]$udt.Rows.Add($row) }

    # Dialog
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Select Users to Remove'
    $dlg.StartPosition = 'CenterParent'
    $dlg.Size = New-Object System.Drawing.Size(520, 440)

    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = 'Fill'; $panel.ColumnCount = 1; $panel.RowCount = 2
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $dg = New-Object System.Windows.Forms.DataGridView
    $dg.Dock = 'Fill'
    $dg.AutoGenerateColumns = $false
    $dg.AllowUserToAddRows = $false
    $dg.RowHeadersVisible = $false

    $cUser = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $cUser.HeaderText = 'User'
    $cUser.DataPropertyName = 'User'
    $cUser.ReadOnly = $true
    $cUser.AutoSizeMode = 'Fill'

    $cSel = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $cSel.HeaderText = 'Remove'
    $cSel.DataPropertyName = 'Remove'
    $cSel.Width = 90

    [void]$dg.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($cUser,$cSel))
    $dg.DataSource = $udt

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.AutoSize = $true

    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Text = 'Remove'
    $btnRemove.AutoSize = $true

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.AutoSize = $true
    $buttons.Dock = 'Top'
    [void]$buttons.Controls.Add($btnRemove)
    [void]$buttons.Controls.Add($btnCancel)

    $panel.Controls.Add($dg, 0, 0)
    $panel.Controls.Add($buttons, 0, 1)
    $dlg.Controls.Add($panel)

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnRemove.Add_Click({
        if ($dg.IsCurrentCellDirty) { $dg.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
        $selected = New-Object System.Collections.Generic.List[string]
        foreach ($r in $udt.Rows) { if ($r['Remove']) { [void]$selected.Add([string]$r['User']) } }
        $dlg.Tag = $selected
        $dlg.Close()
    })

    [void]$dlg.ShowDialog($form)

    $selected = $dlg.Tag
    if ($selected -and $selected.Count -gt 0) {
        foreach ($u in $selected) { Remove-UserColumn -name $u }
    }
})

# Review Add/Remove click handler (opens "Review Changes" window)
$btnPerform.Add_Click({
    if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit); $grid.EndEdit() }
    try { $cm = [System.Windows.Forms.CurrencyManager]$form.BindingContext[$grid.DataSource]; if ($cm) { $cm.EndCurrentEdit() } } catch {}

    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($drv in $grid.DataSource.DefaultView) {
        $row = $drv.Row
        $groupName = [string]$row['Group']
        foreach ($userCol in $userColumns) {
            $curr = [bool]$row[$userCol]
            $orig = [bool]$row["$userCol Original"]
            if ($curr -ne $orig) {
                $action = if ($curr) { 'Add' } else { 'Remove' }
                $changes.Add([pscustomobject]@{
                    FullUser = $userCol
                    Group    = $groupName
                    Action   = $action
                    User     = ($userCol -replace '@.*$','')
                }) | Out-Null
            }
        }
    }

    if ($changes.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No changes detected (no highlighted cells).','Review Add/Remove') | Out-Null
        return
    }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Review Changes'
    $dlg.StartPosition = 'CenterParent'
    $dlg.Size = New-Object System.Drawing.Size(720, 520)

    $cdt = New-Object System.Data.DataTable 'Changes'
    [void]$cdt.Columns.Add('FullUser',[string])
    [void]$cdt.Columns.Add('Group',[string])
    [void]$cdt.Columns.Add('Action',[string])
    [void]$cdt.Columns.Add('User',[string])

    foreach ($c in $changes) {
        $r = $cdt.NewRow()
        $r['FullUser'] = [string]$c.FullUser
        $r['Group']    = [string]$c.Group
        $r['Action']   = [string]$c.Action
        $r['User']     = [string]$c.User
        [void]$cdt.Rows.Add($r)
    }

    $panel = New-Object System.Windows.Forms.TableLayoutPanel
    $panel.Dock = 'Fill'
    $panel.ColumnCount = 1; $panel.RowCount = 2
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $gv = New-Object System.Windows.Forms.DataGridView
    $gv.Dock = 'Fill'
    $gv.AutoGenerateColumns = $false
    $gv.AllowUserToAddRows = $false
    $gv.RowHeadersVisible = $false
    $gv.SelectionMode = 'FullRowSelect'
    $gv.MultiSelect = $false
    $gv.DataSource = $cdt

    $cGrp = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $cGrp.HeaderText = 'Group'
    $cGrp.DataPropertyName = 'Group'
    $cGrp.ReadOnly = $true
    $cGrp.AutoSizeMode = 'Fill'
    $cGrp.FillWeight = 60

    $cAct = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $cAct.HeaderText = 'Action'
    $cAct.DataPropertyName = 'Action'
    $cAct.ReadOnly = $true
    $cAct.Width = 120

    $cUser = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $cUser.HeaderText = 'User'
    $cUser.DataPropertyName = 'User'
    $cUser.ReadOnly = $true
    $cUser.AutoSizeMode = 'Fill'
    $cUser.FillWeight = 40

    [void]$gv.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($cGrp,$cAct,$cUser))

    $gv.EnableHeadersVisualStyles = $false
    $hdr2 = New-Object System.Windows.Forms.DataGridViewCellStyle
    $hdr2.BackColor = [System.Drawing.Color]::MidnightBlue
    $hdr2.ForeColor = [System.Drawing.Color]::FromArgb(240,240,224)
    $hdr2.SelectionBackColor = $hdr2.BackColor
    $hdr2.SelectionForeColor = $hdr2.ForeColor
    $hdr2.Font = New-Object System.Drawing.Font($defaultFont, [System.Drawing.FontStyle]::Bold)
    $hdr2.Padding = New-Object System.Windows.Forms.Padding(8,4,8,4)
    $gv.ColumnHeadersDefaultCellStyle = $hdr2

    $panel.Controls.Add($gv, 0, 0)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.AutoSize = $true
    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })

    $btnNext = New-Object System.Windows.Forms.Button
    $btnNext.Text = 'Next'
    $btnNext.AutoSize = $true
    $btnNext.Add_Click({
        try { $cm2 = [System.Windows.Forms.CurrencyManager]$dlg.BindingContext[$gv.DataSource]; if ($cm2) { $cm2.EndCurrentEdit() } } catch {}
        $out = @()
        foreach ($row in $cdt.Rows) {
            $out += [pscustomobject]@{
                FullUser = [string]$row['FullUser']
                Group    = [string]$row['Group']
                Action   = [string]$row['Action']
                User     = [string]$row['User']
            }
        }
        $dlg.Tag = $out
        $dlg.Close()
    })

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.AutoSize = $true
    $buttons.Dock = 'Top'
    [void]$buttons.Controls.Add($btnNext)
    [void]$buttons.Controls.Add($btnCancel)

    $panel.Controls.Add($buttons, 0, 1)
    $dlg.Controls.Add($panel)

    [void]$dlg.ShowDialog($form)
})

# Export to CSV — current grid state as shown
$btnExport.Add_Click({
    if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit); $grid.EndEdit() }
    try { $cm = [System.Windows.Forms.CurrencyManager]$form.BindingContext[$grid.DataSource]; if ($cm) { $cm.EndCurrentEdit() } } catch {}

    if ($dt.Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No data to export.','Export to CSV') | Out-Null
        return
    }

    $cols = @($grid.Columns | Where-Object { $_.Visible } | Sort-Object DisplayIndex)
    $exportTs = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
    $rows = @()
    foreach ($drv in $grid.DataSource.DefaultView) {
        $r = $drv.Row
        $obj = [ordered]@{ ExportedAt = $exportTs }
        foreach ($col in $cols) {
            if ($userColumns.Contains($col.Name)) {
                $header = $col.Name  # full UPN
                $obj[$header] = [int]([bool]$r[$col.Name])
            } else {
                $header = $col.HeaderText
                $dp = $col.DataPropertyName
                if ([string]::IsNullOrEmpty($dp)) { $obj[$header] = $null } else { $obj[$header] = $r[$dp] }
            }
        }
        $rows += [pscustomobject]$obj
    }

    $docs = [System.Environment]::GetFolderPath('MyDocuments')
    $sfd  = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.InitialDirectory = $docs
    $sfd.FileName = "MembershipReview-$exportTs.csv"
    $sfd.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'

    if ($sfd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $rows | Export-Csv -NoTypeInformation -Path $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Exported $($rows.Count) rows to:`n$($sfd.FileName)", 'Export to CSV') | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to export:`n$($_.Exception.Message)", 'Export to CSV') | Out-Null
        }
    }
})

# Add Credentials — store PSCredential via DPAPI (user-scoped)
$btnCreds.Add_Click({
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Add Credentials'
    $dlg.StartPosition = 'CenterParent'
    $dlg.Size = New-Object System.Drawing.Size(420, 220)

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel
    $tlp.Dock = 'Fill'; $tlp.ColumnCount = 2; $tlp.RowCount = 3
    $tlp.Padding = [System.Windows.Forms.Padding]::new(10)
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = 'Username (UPN or DOMAIN\user):'
    $lblUser.AutoSize = $true

    $tbUser = New-Object System.Windows.Forms.TextBox
    $tbUser.Width = 260

    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = 'Password:'
    $lblPass.AutoSize = $true

    $tbPass = New-Object System.Windows.Forms.TextBox
    $tbPass.Width = 260
    $tbPass.UseSystemPasswordChar = $true

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.AutoSize = $true
    $buttons.Dock = 'Top'

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = 'Save'
    $btnSave.AutoSize = $true

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.AutoSize = $true

    [void]$buttons.Controls.Add($btnSave)
    [void]$buttons.Controls.Add($btnCancel)

    $tlp.Controls.Add($lblUser, 0, 0)
    $tlp.Controls.Add($tbUser, 1, 0)
    $tlp.Controls.Add($lblPass, 0, 1)
    $tlp.Controls.Add($tbPass, 1, 1)
    $tlp.Controls.Add($buttons, 0, 2)
    $tlp.SetColumnSpan($buttons, 2)

    $dlg.Controls.Add($tlp)

    $dlg.AcceptButton = $btnSave
    $dlg.CancelButton = $btnCancel

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnSave.Add_Click({
        $u = ($tbUser.Text).Trim(); $p = $tbPass.Text
        if ([string]::IsNullOrWhiteSpace($u) -or [string]::IsNullOrEmpty($p)) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a username and password.','Add Credentials') | Out-Null
            return
        }
        try {
            $sec  = ConvertTo-SecureString $p -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential($u, $sec)
            $dir  = Join-Path ([System.Environment]::GetFolderPath('ApplicationData')) 'CompareUsersDemo'
            if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
            $path = Join-Path $dir 'credentials.xml'
            $cred | Export-Clixml -Path $path
            [System.Windows.Forms.MessageBox]::Show("Credentials saved securely for:`n$u","Credentials Saved") | Out-Null
            $dlg.Tag = $path
            $dlg.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to save credentials:`n$($_.Exception.Message)", 'Add Credentials') | Out-Null
        }
    })

    [void]$dlg.ShowDialog($form)
})

# Show the form
[void]$form.ShowDialog()

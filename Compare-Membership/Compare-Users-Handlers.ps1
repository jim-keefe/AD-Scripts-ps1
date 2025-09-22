# Handlers for Compare Users Demo (dot-source after main UI is built and functions are loaded)
# Requires controls/vars from main: $form,$grid,$dt,$userColumns,$defaultFont and buttons/inputs.

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

# --- Add single user ---
$btnAddUser.Add_Click({
    $upn = ($txtUser.Text).Trim()
    if ([string]::IsNullOrWhiteSpace($upn)) { return }

    # Prevent duplicates before any directory call
    $norm = [System.Text.RegularExpressions.Regex]::Replace($upn, '\s*\(\d+\)$','').ToLowerInvariant()
    foreach ($uc in $userColumns) {
        $ucNorm = [System.Text.RegularExpressions.Regex]::Replace($uc, '\s*\(\d+\)$','').ToLowerInvariant()
        if ($ucNorm -eq $norm) { [System.Windows.Forms.MessageBox]::Show("User already added:`n$upn","Duplicate User") | Out-Null; return }
    }

    $lookup = Get-UserGroups -UpnOrSam $upn
    if (-not $lookup.Found) { [System.Windows.Forms.MessageBox]::Show("User not found in Active Directory:`n$upn","User Not Found") | Out-Null; return }

    $added = Add-UserColumn -rawName $upn
    if (-not $added) { return }

    $groups = @($lookup.Groups)
    if ($groups -and $groups.Count -gt 0) {
        foreach ($gdn in $groups) { try { $row = Ensure-GroupRow -groupDN ([string]$gdn); if ($row) { $row[$added] = $true } } catch {} }
        foreach ($r in $dt.Rows) { if (-not ($groups -contains [string]$r['DN'])) { $r[$added] = $false } }
    }

    Set-OriginalsForColumn -colName $added
    Update-AllCounts
    $dt.DefaultView.Sort = 'Group ASC'
    $dt.AcceptChanges()
    $txtUser.Clear(); $txtUser.Focus()
})
$txtUser.Add_KeyDown({ param($s,$e) if ($e.KeyCode -eq 'Enter') { $btnAddUser.PerformClick() } })

# --- Bulk Add users dialog ---
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

    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = 'Enter one UPN per line:'; $lbl.AutoSize = $true
    $tb = New-Object System.Windows.Forms.TextBox; $tb.Multiline = $true; $tb.ScrollBars = 'Both'; $tb.WordWrap = $false; $tb.Dock = 'Fill'

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel; $buttons.FlowDirection = 'RightToLeft'; $buttons.AutoSize = $true; $buttons.Dock = 'Top'
    $btnSubmit = New-Object System.Windows.Forms.Button; $btnSubmit.Text = 'Submit'; $btnSubmit.AutoSize = $true
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text = 'Cancel'; $btnCancel.AutoSize = $true
    [void]$buttons.Controls.Add($btnSubmit); [void]$buttons.Controls.Add($btnCancel)

    $panel.Controls.Add($lbl, 0, 0); $panel.Controls.Add($tb, 0, 1); $panel.Controls.Add($buttons, 0, 2)
    $dlg.Controls.Add($panel)

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnSubmit.Add_Click({
        $entries = @($tb.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($entries.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Please enter at least one UPN.','Bulk Add Users') | Out-Null; return }
        $dlg.Tag = $entries; $dlg.Close()
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
                foreach ($gdn in $groups) { try { $row = Ensure-GroupRow -groupDN ([string]$gdn); if ($row) { $row[$added] = $true } } catch {} }
                foreach ($r in $dt.Rows) { if (-not ($groups -contains [string]$r['DN'])) { $r[$added] = $false } }
            }
            Set-OriginalsForColumn -colName $added
        }
        $dt.DefaultView.Sort = 'Group ASC'
        Update-AllCounts
        $dt.AcceptChanges()
        if ($notFound.Count -gt 0 -or $duplicates.Count -gt 0) {
            $parts = @(); if ($notFound.Count -gt 0) { $parts += "Not found:`n" + ([string]::Join("`n", $notFound)) }
            if ($duplicates.Count -gt 0) { $parts += "Duplicates (skipped):`n" + ([string]::Join("`n", $duplicates)) }
            [System.Windows.Forms.MessageBox]::Show([string]::Join("`n`n", $parts),'Bulk Add Summary') | Out-Null
        }
    }
})

# --- Get Users (search AD by attributes; show results in Out-GridView) ---
$btnGetUsers.Add_Click({
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Find Users'
    $dlg.StartPosition = 'CenterParent'
    $dlg.Size = New-Object System.Drawing.Size(520, 360)

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel
    $tlp.Dock = 'Fill'
    $tlp.ColumnCount = 2
    $tlp.RowCount = 6
    $tlp.Padding = [System.Windows.Forms.Padding]::new(10)
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    foreach ($i in 0..4) { [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize)) }
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text = 'Title:'; $lblTitle.AutoSize = $true
    $tbTitle  = New-Object System.Windows.Forms.TextBox; $tbTitle.Width = 320
    $lblEmpT  = New-Object System.Windows.Forms.Label; $lblEmpT.Text = 'Employee Type:'; $lblEmpT.AutoSize = $true
    $tbEmpT   = New-Object System.Windows.Forms.TextBox; $tbEmpT.Width = 320
    $lblDept  = New-Object System.Windows.Forms.Label; $lblDept.Text = 'Department:'; $lblDept.AutoSize = $true
    $tbDept   = New-Object System.Windows.Forms.TextBox; $tbDept.Width = 320
    $lblOff   = New-Object System.Windows.Forms.Label; $lblOff.Text = 'Office:'; $lblOff.AutoSize = $true
    $tbOff    = New-Object System.Windows.Forms.TextBox; $tbOff.Width = 320

    $lblNote  = New-Object System.Windows.Forms.Label; $lblNote.Text = 'Note: All fields use a contains match (wildcard prefix).'; $lblNote.AutoSize = $true; $lblNote.Margin = '0,8,0,6'

    $btns = New-Object System.Windows.Forms.FlowLayoutPanel; $btns.FlowDirection = 'RightToLeft'; $btns.AutoSize = $true; $btns.Dock='Top'
    $btnOK = New-Object System.Windows.Forms.Button; $btnOK.Text='OK'; $btnOK.AutoSize=$true
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text='Cancel'; $btnCancel.AutoSize=$true
    [void]$btns.Controls.Add($btnOK); [void]$btns.Controls.Add($btnCancel)

    $tlp.Controls.Add($lblTitle,0,0); $tlp.Controls.Add($tbTitle,1,0)
    $tlp.Controls.Add($lblEmpT,0,1);  $tlp.Controls.Add($tbEmpT,1,1)
    $tlp.Controls.Add($lblDept,0,2);  $tlp.Controls.Add($tbDept,1,2)
    $tlp.Controls.Add($lblOff,0,3);   $tlp.Controls.Add($tbOff,1,3)
    $tlp.Controls.Add($lblNote,0,4);  $tlp.SetColumnSpan($lblNote,2)
    $tlp.Controls.Add($btns,0,5);     $tlp.SetColumnSpan($btns,2)

    $dlg.Controls.Add($tlp)

    $dlg.AcceptButton = $btnOK
    $dlg.CancelButton = $btnCancel

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnOK.Add_Click({
        $title = ($tbTitle.Text).Trim()
        $empT  = ($tbEmpT.Text).Trim()
        $dept  = ($tbDept.Text).Trim()
        $off   = ($tbOff.Text).Trim()

        function _EscLdap([string]$s) {
            if ([string]::IsNullOrEmpty($s)) { return $s }
            try { return [System.DirectoryServices.Protocols.LdapFilter]::Escape($s) } catch { return ($s -replace '([\\*\(\)\\])','\\$1') }
        }

        $clauses = @('(&(objectCategory=person)(objectClass=user)')
        if ($title) { $clauses += '(title=*' + (_EscLdap $title) + '*)' }
        if ($empT)  { $clauses += '(employeeType=*' + (_EscLdap $empT) + '*)' }
        if ($dept)  { $clauses += '(department=*' + (_EscLdap $dept) + '*)' }
        if ($off)   { $clauses += '(physicalDeliveryOfficeName=*' + (_EscLdap $off) + '*)' }
        $ldap = [string]::Concat($clauses) + ')'

        $results = @()
        try {
            if (Get-Module -ListAvailable -Name ActiveDirectory) {
                Import-Module ActiveDirectory -ErrorAction SilentlyContinue | Out-Null
                $props = 'title','employeeType','department','physicalDeliveryOfficeName','userPrincipalName','sAMAccountName','name'
                $results = Get-ADUser -LDAPFilter $ldap -Properties $props | Select-Object @{n='Name';e={$_.Name}}, @{n='SamAccountName';e={$_.SamAccountName}}, @{n='UserPrincipalName';e={$_.UserPrincipalName}}, @{n='Title';e={$_.Title}}, @{n='EmployeeType';e={$_.EmployeeType}}, @{n='Department';e={$_.Department}}, @{n='Office';e={$_.physicalDeliveryOfficeName}}
            } else {
                $root = New-Object System.DirectoryServices.DirectoryEntry
                $srch = New-Object System.DirectoryServices.DirectorySearcher($root)
                $srch.Filter = $ldap
                $srch.PageSize = 1000
                foreach ($p in 'name','samaccountname','userprincipalname','title','employeetype','department','physicaldeliveryofficename') { [void]$srch.PropertiesToLoad.Add($p) }
                $col = $srch.FindAll()
                foreach ($res in $col) {
                    $p = $res.Properties
                    $results += [pscustomobject]@{
                        Name = ($p['name'] | Select-Object -First 1)
                        SamAccountName = ($p['samaccountname'] | Select-Object -First 1)
                        UserPrincipalName = ($p['userprincipalname'] | Select-Object -First 1)
                        Title = ($p['title'] | Select-Object -First 1)
                        EmployeeType = ($p['employeetype'] | Select-Object -First 1)
                        Department = ($p['department'] | Select-Object -First 1)
                        Office = ($p['physicaldeliveryofficename'] | Select-Object -First 1)
                    }
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Search failed:`n$($_.Exception.Message)", 'Find Users') | Out-Null
        }

        if (-not $results -or $results.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('No users found with the given criteria.','Find Users') | Out-Null
        } else {
            $null = $results | Out-GridView -Title ("User Search Results (" + $results.Count + ")")
        }
    })

    [void]$dlg.ShowDialog($form)
})

# --- Remove Users: All ---
$btnRemoveAll.Add_Click({
    if ($userColumns.Count -eq 0 -and $dt.Rows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Nothing to remove.','Remove All') | Out-Null; return }
    try {
        $cols = @($userColumns.ToArray()); foreach ($uc in $cols) { Remove-UserColumn -name $uc }
        $dt.Rows.Clear(); Update-AllCounts; $dt.AcceptChanges()
    } catch { [System.Windows.Forms.MessageBox]::Show("Failed to remove all:`n$($_.Exception.Message)",'Remove All') | Out-Null }
})

# --- Remove Users: Select ---
$btnRemoveSelect.Add_Click({
    if ($userColumns.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('No user columns to remove.','Remove Users') | Out-Null; return }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Remove Users'; $dlg.StartPosition = 'CenterParent'; $dlg.Size = New-Object System.Drawing.Size(420, 420)

    $udt = New-Object System.Data.DataTable 'Users'
    [void]$udt.Columns.Add('Remove',[bool]); [void]$udt.Columns.Add('User',[string]); [void]$udt.Columns.Add('FullUser',[string])
    foreach ($uc in $userColumns) { $r = $udt.NewRow(); $r['Remove']=$false; $r['User']=($uc -replace '@.*$',''); $r['FullUser']=$uc; [void]$udt.Rows.Add($r) }

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel; $tlp.Dock = 'Fill'; $tlp.ColumnCount = 1; $tlp.RowCount = 2
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $gv = New-Object System.Windows.Forms.DataGridView; $gv.Dock='Fill'; $gv.AutoGenerateColumns=$false; $gv.AllowUserToAddRows=$false; $gv.RowHeadersVisible=$false; $gv.DataSource=$udt
    $cSel = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn; $cSel.HeaderText='Remove'; $cSel.DataPropertyName='Remove'; $cSel.Width=80
    $cUser= New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $cUser.HeaderText='User'; $cUser.DataPropertyName='User'; $cUser.ReadOnly=$true; $cUser.AutoSizeMode='Fill'
    $cFull= New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $cFull.HeaderText='FullUser'; $cFull.DataPropertyName='FullUser'; $cFull.Visible=$false
    [void]$gv.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($cSel,$cUser,$cFull))

    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text='Cancel'; $btnCancel.AutoSize=$true
    $btnRemove = New-Object System.Windows.Forms.Button; $btnRemove.Text='Remove'; $btnRemove.AutoSize=$true
    $panelButtons = New-Object System.Windows.Forms.FlowLayoutPanel; $panelButtons.FlowDirection='RightToLeft'; $panelButtons.AutoSize=$true; $panelButtons.Dock='Top'
    [void]$panelButtons.Controls.Add($btnRemove); [void]$panelButtons.Controls.Add($btnCancel)

    $tlp.Controls.Add($gv,0,0); $tlp.Controls.Add($panelButtons,0,1); $dlg.Controls.Add($tlp)

    $btnCancel.Add_Click({ $dlg.Tag = $null; $dlg.Close() })
    $btnRemove.Add_Click({
        if ($gv.IsCurrentCellDirty) { $gv.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit); $gv.EndEdit() }
        $toRemove = @($udt.Rows | Where-Object { $_['Remove'] -eq $true })
        if ($toRemove.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Select at least one user to remove.','Remove Users') | Out-Null; return }
        $dlg.Tag = @($toRemove | ForEach-Object { [string]$_['FullUser'] }); $dlg.Close()
    })

    [void]$dlg.ShowDialog($form)
    $selected = $dlg.Tag
    if ($selected) { foreach ($uc in $selected) { Remove-UserColumn -name $uc }; Update-AllCounts; $dt.AcceptChanges() }
})

# --- Review Add/Remove (opens Review Changes window) ---
$btnPerform.Add_Click({
    if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit); $grid.EndEdit() }
    try { $cm = [System.Windows.Forms.CurrencyManager]$form.BindingContext[$grid.DataSource]; if ($cm) { $cm.EndCurrentEdit() } } catch {}

    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($drv in $grid.DataSource.DefaultView) {
        $row = $drv.Row; $groupName = [string]$row['Group']
        foreach ($userCol in $userColumns) {
            $curr = [bool]$row[$userCol]; $orig = [bool]$row["$userCol Original"]
            if ($curr -ne $orig) { $changes.Add([pscustomobject]@{ FullUser=$userCol; Group=$groupName; Action=(if ($curr){'Add'} else {'Remove'}); User=($userCol -replace '@.*$','') }) | Out-Null }
        }
    }
    if ($changes.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('No changes detected (no highlighted cells).','Review Add/Remove') | Out-Null; return }

    $dlg = New-Object System.Windows.Forms.Form; $dlg.Text = 'Review Changes'; $dlg.StartPosition = 'CenterParent'; $dlg.Size = New-Object System.Drawing.Size(720, 520)
    $cdt = New-Object System.Data.DataTable 'Changes'; [void]$cdt.Columns.Add('FullUser',[string]); [void]$cdt.Columns.Add('Group',[string]); [void]$cdt.Columns.Add('Action',[string]); [void]$cdt.Columns.Add('User',[string])
    foreach ($c in $changes) { $r = $cdt.NewRow(); $r['FullUser']=[string]$c.FullUser; $r['Group']=[string]$c.Group; $r['Action']=[string]$c.Action; $r['User']=[string]$c.User; [void]$cdt.Rows.Add($r) }

    $panel = New-Object System.Windows.Forms.TableLayoutPanel; $panel.Dock='Fill'; $panel.ColumnCount=1; $panel.RowCount=2
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    [void]$panel.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $gv = New-Object System.Windows.Forms.DataGridView; $gv.Dock='Fill'; $gv.AutoGenerateColumns=$false; $gv.AllowUserToAddRows=$false; $gv.RowHeadersVisible=$false; $gv.SelectionMode='FullRowSelect'; $gv.MultiSelect=$false; $gv.DataSource=$cdt
    $cGrp = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $cGrp.HeaderText='Group'; $cGrp.DataPropertyName='Group'; $cGrp.ReadOnly=$true; $cGrp.AutoSizeMode='Fill'; $cGrp.FillWeight=60
    $cAct = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $cAct.HeaderText='Action'; $cAct.DataPropertyName='Action'; $cAct.ReadOnly=$true; $cAct.Width=120
    $cUser= New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $cUser.HeaderText='User'; $cUser.DataPropertyName='User'; $cUser.ReadOnly=$true; $cUser.AutoSizeMode='Fill'; $cUser.FillWeight=40
    [void]$gv.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($cGrp,$cAct,$cUser))

    $gv.EnableHeadersVisualStyles = $false
    $hdr2 = New-Object System.Windows.Forms.DataGridViewCellStyle; $hdr2.BackColor=[System.Drawing.Color]::MidnightBlue; $hdr2.ForeColor=[System.Drawing.Color]::FromArgb(240,240,224)
    $hdr2.SelectionBackColor=$hdr2.BackColor; $hdr2.SelectionForeColor=$hdr2.ForeColor
    $hdr2.Font = New-Object System.Drawing.Font($defaultFont, [System.Drawing.FontStyle]::Bold); $hdr2.Padding = New-Object System.Windows.Forms.Padding(8,4,8,4)
    $gv.ColumnHeadersDefaultCellStyle=$hdr2

    $panel.Controls.Add($gv,0,0)

    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text='Cancel'; $btnCancel.AutoSize=$true; $btnCancel.Add_Click({ $dlg.Tag=$null; $dlg.Close() })
    $btnNext = New-Object System.Windows.Forms.Button; $btnNext.Text='Next'; $btnNext.AutoSize=$true; $btnNext.Add_Click({ try { $cm2 = [System.Windows.Forms.CurrencyManager]$dlg.BindingContext[$gv.DataSource]; if ($cm2) { $cm2.EndCurrentEdit() } } catch {}; $dlg.Tag=$cdt.Rows; $dlg.Close() })

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel; $buttons.FlowDirection='RightToLeft'; $buttons.AutoSize=$true; $buttons.Dock='Top'
    [void]$buttons.Controls.Add($btnNext); [void]$buttons.Controls.Add($btnCancel)

    $panel.Controls.Add($buttons,0,1); $dlg.Controls.Add($panel)
    [void]$dlg.ShowDialog($form)
})

# --- Export to CSV (current grid state; full UPN headers; 1/0 + ExportedAt) ---
$btnExport.Add_Click({
    if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit); $grid.EndEdit() }
    try { $cm = [System.Windows.Forms.CurrencyManager]$form.BindingContext[$grid.DataSource]; if ($cm) { $cm.EndCurrentEdit() } } catch {}

    if ($dt.Rows.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('No data to export.','Export to CSV') | Out-Null; return }

    $cols = @($grid.Columns | Where-Object { $_.Visible } | Sort-Object DisplayIndex)
    $exportTs = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
    $rows = @()
    foreach ($drv in $grid.DataSource.DefaultView) {
        $r = $drv.Row; $obj = [ordered]@{ ExportedAt = $exportTs }
        foreach ($col in $cols) {
            if ($userColumns.Contains($col.Name)) { $obj[$col.Name] = [int]([bool]$r[$col.Name]) } # header = full UPN
            else { $dp = $col.DataPropertyName; $obj[$col.HeaderText] = (if ([string]::IsNullOrEmpty($dp)) { $null } else { $r[$dp] }) }
        }
        $rows += [pscustomobject]$obj
    }

    $docs = [System.Environment]::GetFolderPath('MyDocuments')
    $sfd  = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.InitialDirectory = $docs; $sfd.FileName = "MembershipReview-$exportTs.csv"; $sfd.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
    if ($sfd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        try { $rows | Export-Csv -NoTypeInformation -Path $sfd.FileName -Encoding UTF8; [System.Windows.Forms.MessageBox]::Show("Exported $($rows.Count) rows to:`n$($sfd.FileName)", 'Export to CSV') | Out-Null }
        catch { [System.Windows.Forms.MessageBox]::Show("Failed to export:`n$($_.Exception.Message)", 'Export to CSV') | Out-Null }
    }
})

# --- Add Credentials (DPAPI user-scoped via Export-Clixml) ---
$btnCreds.Add_Click({
    $dlg = New-Object System.Windows.Forms.Form; $dlg.Text='Add Credentials'; $dlg.StartPosition='CenterParent'; $dlg.Size = New-Object System.Drawing.Size(420, 220)

    $tlp = New-Object System.Windows.Forms.TableLayoutPanel; $tlp.Dock='Fill'; $tlp.ColumnCount=2; $tlp.RowCount=3; $tlp.Padding=[System.Windows.Forms.Padding]::new(10)
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
    [void]$tlp.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

    $lblUser = New-Object System.Windows.Forms.Label; $lblUser.Text='Username (UPN or DOMAIN\\user):'; $lblUser.AutoSize=$true
    $tbUser = New-Object System.Windows.Forms.TextBox; $tbUser.Width=260
    $lblPass = New-Object System.Windows.Forms.Label; $lblPass.Text='Password:'; $lblPass.AutoSize=$true
    $tbPass = New-Object System.Windows.Forms.TextBox; $tbPass.Width=260; $tbPass.UseSystemPasswordChar=$true

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel; $buttons.FlowDirection='RightToLeft'; $buttons.AutoSize=$true; $buttons.Dock='Top'
    $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text='Save'; $btnSave.AutoSize=$true
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text='Cancel'; $btnCancel.AutoSize=$true
    [void]$buttons.Controls.Add($btnSave); [void]$buttons.Controls.Add($btnCancel)

    $tlp.Controls.Add($lblUser,0,0); $tlp.Controls.Add($tbUser,1,0); $tlp.Controls.Add($lblPass,0,1); $tlp.Controls.Add($tbPass,1,1); $tlp.Controls.Add($buttons,0,2); $tlp.SetColumnSpan($buttons,2)
    $dlg.Controls.Add($tlp)

    $dlg.AcceptButton=$btnSave; $dlg.CancelButton=$btnCancel

    $btnCancel.Add_Click({ $dlg.Tag=$null; $dlg.Close() })
    $btnSave.Add_Click({
        $u = ($tbUser.Text).Trim(); $p = $tbPass.Text
        if ([string]::IsNullOrWhiteSpace($u) -or [string]::IsNullOrEmpty($p)) { [System.Windows.Forms.MessageBox]::Show('Please enter a username and password.','Add Credentials') | Out-Null; return }
        try {
            $sec  = ConvertTo-SecureString $p -AsPlainText -Force
            $cred = New-Object System.Management.Automation.PSCredential($u, $sec)
            $dir  = Join-Path ([System.Environment]::GetFolderPath('ApplicationData')) 'CompareUsersDemo'
            if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
            $path = Join-Path $dir 'credentials.xml'
            $cred | Export-Clixml -Path $path
            [System.Windows.Forms.MessageBox]::Show("Credentials saved securely for:`n$u","Credentials Saved") | Out-Null
            $dlg.Tag = $path; $dlg.Close()
        } catch { [System.Windows.Forms.MessageBox]::Show("Failed to save credentials:`n$($_.Exception.Message)", 'Add Credentials') | Out-Null }
    })

    [void]$dlg.ShowDialog($form)
})

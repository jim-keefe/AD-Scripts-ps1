# Main script for Compare Users Demo
# This script builds the UI and layout, then dot-sources the functions and handlers files.

# --- Ensure STA & Windows PowerShell for WinForms ---
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA -or ($PSVersionTable.PSEdition -ne 'Desktop')) {
    $psExe = "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
    $args  = @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    Start-Process -FilePath $psExe -ArgumentList $args | Out-Null
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Compare Users Demo'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(1100, 650)
$form.BackColor = [System.Drawing.Color]::Gainsboro  # light grey background

$defaultFont = $form.Font
$familyName  = $defaultFont.FontFamily.Name
$newSizePt   = [single]([math]::Max(6, $defaultFont.SizeInPoints + 2))
try { $titleFont = New-Object System.Drawing.Font($familyName, $newSizePt, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point) }
catch { $titleFont = New-Object System.Drawing.Font($defaultFont, [System.Drawing.FontStyle]::Bold) }

# Track dynamic user columns here
$userColumns = New-Object System.Collections.Generic.List[string]

# ---------- Root layout ----------
$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock = 'Fill'; $root.ColumnCount = 1; $root.RowCount = 3; $root.RowStyles.Clear()
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))         # top
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::Percent, 100))     # middle
$root.RowStyles.Add([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize))         # bottom
$form.Controls.Add($root)

# GroupBox white border painter
$gbBorderPaint = { param($s,$e)
    try {
        $g=$e.Graphics; $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White)
        try {
            $sz=[System.Windows.Forms.TextRenderer]::MeasureText($s.Text,$s.Font); $yTop=[int]([math]::Max(2,[math]::Round($sz.Height/2.0)))
            $rect=$s.ClientRectangle; $l=1; $r=$rect.Width-2; $b=$rect.Height-2; $gapL=8; $gapR=[math]::Min($r,$gapL+$sz.Width)
            if ($gapL -gt $l) { $g.DrawLine($pen,$l,$yTop,$gapL-2,$yTop) }
            $g.DrawLine($pen,$gapR,$yTop,$r,$yTop); $g.DrawLine($pen,$l,$yTop,$l,$b); $g.DrawLine($pen,$r,$yTop,$r,$b); $g.DrawLine($pen,$l,$b,$r,$b)
        } finally { $pen.Dispose() }
    } catch {}
}

# ---------- Top row: Add Users (left) | Remove Users (right) ----------
$topRow = New-Object System.Windows.Forms.TableLayoutPanel; $topRow.Dock='Top'; $topRow.AutoSize=$true; $topRow.ColumnCount=2; $topRow.RowCount=1
$topRow.ColumnStyles.Clear();
[void]$topRow.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,70))
[void]$topRow.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,30))
$root.Controls.Add($topRow,0,0)

# Left: Add Users
$gbAdd = New-Object System.Windows.Forms.GroupBox; $gbAdd.Text='Add Users for Review'; $gbAdd.Dock='Fill'; $gbAdd.AutoSize=$true
$gbAdd.Padding=[System.Windows.Forms.Padding]::new(15,15,15,15); $gbAdd.Font=$titleFont; $gbAdd.ForeColor=[System.Drawing.Color]::MidnightBlue; $gbAdd.Margin='0,3,0,0'
$topRow.Controls.Add($gbAdd); $topRow.SetColumn($gbAdd,0); $gbAdd.add_Paint($gbBorderPaint)

$addInner = New-Object System.Windows.Forms.TableLayoutPanel; $addInner.Dock='Top'; $addInner.AutoSize=$true; $addInner.Font=$defaultFont; $addInner.ForeColor=[System.Drawing.SystemColors]::ControlText
$addInner.ColumnCount=5; $addInner.RowCount=1
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
[void]$addInner.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
$gbAdd.Controls.Add($addInner)

$lblUpn = New-Object System.Windows.Forms.Label; $lblUpn.Text='UPN/SAM:'; $lblUpn.AutoSize=$true; $lblUpn.Margin='3,6,3,3'; $lblUpn.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
$txtUser = New-Object System.Windows.Forms.TextBox; $txtUser.Width=360; $txtUser.Anchor='Left,Right'
$btnAddUser = New-Object System.Windows.Forms.Button; $btnAddUser.Text='Add User'; $btnAddUser.AutoSize=$true
$btnBulkAdd = New-Object System.Windows.Forms.Button; $btnBulkAdd.Text='Bulk Add'; $btnBulkAdd.AutoSize=$true
$btnGetUsers = New-Object System.Windows.Forms.Button; $btnGetUsers.Text='Get Users'; $btnGetUsers.AutoSize=$true
[void]$addInner.Controls.Add($lblUpn,0,0); [void]$addInner.Controls.Add($txtUser,1,0); [void]$addInner.Controls.Add($btnAddUser,2,0); [void]$addInner.Controls.Add($btnBulkAdd,3,0); [void]$addInner.Controls.Add($btnGetUsers,4,0)

# Right: Remove Users
$gbRemove = New-Object System.Windows.Forms.GroupBox; $gbRemove.Text='Remove Users for Review'; $gbRemove.Dock='Top'; $gbRemove.AutoSize=$true; $gbRemove.AutoSizeMode=[System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$gbRemove.MinimumSize=New-Object System.Drawing.Size(220,0); $gbRemove.Margin='8,3,0,0'; $gbRemove.Padding=[System.Windows.Forms.Padding]::new(15,15,15,15); $gbRemove.Font=$titleFont; $gbRemove.ForeColor=[System.Drawing.Color]::MidnightBlue
$topRow.Controls.Add($gbRemove); $topRow.SetColumn($gbRemove,1); $gbRemove.add_Paint($gbBorderPaint)

$remInner = New-Object System.Windows.Forms.FlowLayoutPanel; $remInner.Dock='Top'; $remInner.AutoSize=$true; $remInner.FlowDirection='LeftToRight'; $remInner.WrapContents=$false; $remInner.Font=$defaultFont; $remInner.ForeColor=[System.Drawing.SystemColors]::ControlText
$gbRemove.Controls.Add($remInner)
$btnRemoveSelect = New-Object System.Windows.Forms.Button; $btnRemoveSelect.Text='Select'; $btnRemoveSelect.AutoSize=$true
$btnRemoveAll = New-Object System.Windows.Forms.Button; $btnRemoveAll.Text='All'; $btnRemoveAll.AutoSize=$true
[void]$remInner.Controls.Add($btnRemoveSelect); [void]$remInner.Controls.Add($btnRemoveAll)

# ---------- Middle: Grid ----------
$gbGrid = New-Object System.Windows.Forms.GroupBox; $gbGrid.Text='Group Comparison for Users'; $gbGrid.Dock='Fill'; $gbGrid.Padding=[System.Windows.Forms.Padding]::new(15,15,15,15); $gbGrid.Font=$titleFont; $gbGrid.ForeColor=[System.Drawing.Color]::MidnightBlue
$root.Controls.Add($gbGrid,0,1); $gbGrid.add_Paint($gbBorderPaint)

$grid = New-Object System.Windows.Forms.DataGridView; $grid.Dock='Fill'; $grid.AllowUserToAddRows=$false; $grid.AllowUserToDeleteRows=$false; $grid.RowHeadersVisible=$false; $grid.AutoGenerateColumns=$false
$grid.SelectionMode='FullRowSelect'; $grid.MultiSelect=$false; $grid.AutoSizeColumnsMode='Fill'; $grid.EditMode=[System.Windows.Forms.DataGridViewEditMode]::EditOnEnter; $grid.Font=$defaultFont; $grid.ForeColor=[System.Drawing.SystemColors]::ControlText
$grid.DefaultCellStyle.Font=$defaultFont; $grid.DefaultCellStyle.ForeColor=[System.Drawing.SystemColors]::ControlText; $gbGrid.Controls.Add($grid)

# Data model & base columns
$dt = New-Object System.Data.DataTable 'Demo'
[void]$dt.Columns.Add('Group',[string]); [void]$dt.Columns.Add('Count',[int]); [void]$dt.Columns.Add('Description',[string]); [void]$dt.Columns.Add('DN',[string])
$grid.DataSource=$dt

$colGroup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colGroup.HeaderText='Group'; $colGroup.DataPropertyName='Group'; $colGroup.Name='Group'; $colGroup.ReadOnly=$true
$colCount = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colCount.HeaderText='Count'; $colCount.DataPropertyName='Count'; $colCount.Name='Count'; $colCount.ReadOnly=$true; $colCount.AutoSizeMode='AllCells'; $colCount.DefaultCellStyle.Alignment=[System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$colDesc  = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colDesc.HeaderText='Description'; $colDesc.DataPropertyName='Description'; $colDesc.Name='Description'; $colDesc.ReadOnly=$true
$colDN    = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $colDN.HeaderText='DN'; $colDN.DataPropertyName='DN'; $colDN.Name='DN'; $colDN.ReadOnly=$true
[void]$grid.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@($colGroup,$colCount,$colDesc,$colDN))

# Zebra stripes & header styling
$grid.RowsDefaultCellStyle.BackColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray
$grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.SystemColors]::ControlText
$grid.RowsDefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::LightGray

$grid.EnableHeadersVisualStyles=$false
$hdr = New-Object System.Windows.Forms.DataGridViewCellStyle; $hdr.BackColor=[System.Drawing.Color]::MidnightBlue; $hdr.ForeColor=[System.Drawing.Color]::FromArgb(240,240,224)
$hdr.SelectionBackColor=$hdr.BackColor; $hdr.SelectionForeColor=$hdr.ForeColor; $hdr.Font=New-Object System.Drawing.Font($defaultFont,[System.Drawing.FontStyle]::Bold); $hdr.Padding=New-Object System.Windows.Forms.Padding(8,4,8,4)
$grid.ColumnHeadersDefaultCellStyle=$hdr; $grid.ColumnHeadersHeightSizeMode=[System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize

# Make the Group column bold
$boldGroupFont = New-Object System.Drawing.Font($defaultFont.FontFamily, [single]$defaultFont.SizeInPoints, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$colGroup.DefaultCellStyle.Font = $boldGroupFont

# ---------- Bottom: Actions group ----------
$gbActions = New-Object System.Windows.Forms.GroupBox; $gbActions.Text='Actions'; $gbActions.Dock='Top'; $gbActions.AutoSize=$true; $gbActions.Padding=[System.Windows.Forms.Padding]::new(15,15,15,15)
$gbActions.Font=$titleFont; $gbActions.ForeColor=[System.Drawing.Color]::MidnightBlue; $root.Controls.Add($gbActions,0,2); $gbActions.add_Paint($gbBorderPaint)

# Layout: left-aligned "Add Credentials"; right-aligned "Export" + "Review"
$actionsTable = New-Object System.Windows.Forms.TableLayoutPanel; $actionsTable.Dock='Top'; $actionsTable.AutoSize=$true; $actionsTable.ColumnCount=3; $actionsTable.RowCount=1
$actionsTable.ColumnStyles.Clear()
[void]$actionsTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
[void]$actionsTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
[void]$actionsTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
$gbActions.Controls.Add($actionsTable)

$btnCreds = New-Object System.Windows.Forms.Button; $btnCreds.Text='Add Credentials'; $btnCreds.AutoSize=$true; $btnCreds.Margin='6,6,6,6'; $btnCreds.Padding='10,6,10,6'
[void]$actionsTable.Controls.Add($btnCreds,0,0)

$actionsRight = New-Object System.Windows.Forms.FlowLayoutPanel; $actionsRight.FlowDirection='RightToLeft'; $actionsRight.AutoSize=$true; $actionsRight.AutoSizeMode=[System.Windows.Forms.AutoSizeMode]::GrowAndShrink; $actionsRight.WrapContents=$false; $actionsRight.Dock='Top'
$btnPerform = New-Object System.Windows.Forms.Button; $btnPerform.Text='Review Add/Remove'; $btnPerform.AutoSize=$true; $btnPerform.Margin='6,6,6,6'; $btnPerform.Padding='10,6,10,6'
$btnExport  = New-Object System.Windows.Forms.Button; $btnExport.Text='Export to CSV'; $btnExport.AutoSize=$true; $btnExport.Margin='6,6,6,6'; $btnExport.Padding='10,6,10,6'
[void]$actionsRight.Controls.Add($btnPerform)  # rightmost
[void]$actionsRight.Controls.Add($btnExport)   # to the left of Review
[void]$actionsTable.Controls.Add($actionsRight,2,0)

# ---------- Load functions & handlers ----------
. (Join-Path $PSScriptRoot 'Compare-Users-Functions.ps1')
. (Join-Path $PSScriptRoot 'Compare-Users-Handlers.ps1')

# Show the form
[void]$form.ShowDialog()

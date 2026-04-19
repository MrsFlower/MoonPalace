Add-Type -AssemblyName System.windows.forms
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = 'Select a Game Project Folder'
$folderBrowser.SelectedPath = (Get-Item -Path '..\Projects').FullName
if ($folderBrowser.ShowDialog() -eq 'OK') {
    [IO.File]::WriteAllText('picked_folder.txt', $folderBrowser.SelectedPath)
} else {
    [IO.File]::WriteAllText('picked_folder.txt', 'CANCELLED')
}

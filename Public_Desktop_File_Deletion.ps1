# Script used to remove a specific file from the Public Profile's Desktop
# Replace "Application.lnk" with the correct file
  $pathOfFile = "C:\Users\Public\Desktop\Application.lnk" # Initialize the file
  Remove-Item -Path $pathOfFile # Delete the file

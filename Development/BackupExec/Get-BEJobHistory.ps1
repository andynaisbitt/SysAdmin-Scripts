Get-BEJobHistory -JobStatus Error -FromStartTime (Get-Date).AddHours(-12) | ft -auto 

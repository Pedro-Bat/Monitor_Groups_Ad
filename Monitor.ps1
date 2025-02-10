# Configurações de e-mail
$smtpServer = "host.smtpserver"
$smtpPort = 25 
$senderEmail = "Gestao.grupos@dominio.com"
$receiverEmail = "email@dominio.com"
$subject = "Alterações no grupo do Active Directory"

$grupos = @()
#Grupos para serem monitorados
$grupos = "Admins. do domínio","Enterprise Admins","Administradores","Administradores DHCP","Admins Exchange"
foreach($grupo in $grupos){


# Caminho completo para o arquivo de registro
$logFile = "C:\bat\$grupo"

$ServerName = $env:COMPUTERNAME

$IP = Test-Connection -ComputerName $ServerName -Count 1 | Select-Object -ExpandProperty IPV4Address | Select-Object -ExpandProperty IPAddressToString

# Verifica se o arquivo de registro existe, caso contrario, cria-o.
if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force | Out-Null
}

# Obter lista de membros atual
$oldMembers = Get-ADGroupMember -Identity $grupo | Select-Object -ExpandProperty SamAccountName

# Obter lista de membros anterior do arquivo de registro
$previousMembers = Get-Content $logFile

# Verificar alterações
$addedMembers = Compare-Object -ReferenceObject $previousMembers -DifferenceObject $oldMembers |
               Where-Object { $_.SideIndicator -eq "=>" } |
               Select-Object -ExpandProperty InputObject

$removedMembers = Compare-Object -ReferenceObject $previousMembers -DifferenceObject $oldMembers |
                 Where-Object { $_.SideIndicator -eq "<=" } |
                 Select-Object -ExpandProperty InputObject

# Atualizar o arquivo de registro com a nova lista de membros
$oldMembers | Set-Content $logFile

# Enviar e-mail com as alterações
if ($addedMembers -or $removedMembers) {
    $body = "<html>"
    $body += "<head>"
    $body += "<style>"
    $body += "body { font-family: Arial, sans-serif; }"
    $body += "h1 { font-size: 18px; font-weight: bold; }"
    $body += "p { font-size: 14px; }"
    $body += "ul { margin-top: 10px; margin-bottom: 10px; }"
    $body += "</style>"
    $body += "</head>"
    $body += "<body>"
    $body += "<h1>Foram detectadas alterações no grupo $grupo :</h1>"
	$body += "<h2>Server: $ServerName [ $IP ]</h2>"
    
    if ($addedMembers) {
        $body += "<p>Membros adicionados:</p>"
        $body += "<ul>"
        foreach ($member in $addedMembers) {
            $body += "<li>$member</li>"
        }
        $body += "</ul>"
    }
    
    if ($removedMembers) {
        $body += "<p>Membros removidos:</p>"
        $body += "<ul>"
        foreach ($member in $removedMembers) {
            $body += "<li>$member</li>"
        }
        $body += "</ul>"
    }
    
    $body += "</body>"
    $body += "</html>"
    
    # Configurar e enviar e-mail
    $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
    $mailMessage = New-Object System.Net.Mail.MailMessage($senderEmail, $receiverEmail, $subject, $body)
    $mailMessage.IsBodyHtml = $true
    
     
    $smtp.Send($mailMessage)
  }

}

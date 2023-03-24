#AUTO-IP CHANGER
function Test-Administrator {
  #Preverjamo če je skripta zagnana kot administrator.
  $user = [Security.Principal.WindowsIdentity]::GetCurrent();
  $bool_admin = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if (-Not $bool_admin) {
  Write-Host "Skripto je potrebno zagnati kot administrator."
  timeout /t 5
  exit
  }
}
function spremenljivka_network {
  #Preverjamo če je uproabnik uporabil pravilen zapis omrežja.
  $zanka = $true
  $bool_dolzina_niza = $false
  $bool_posamezen_segment = $false
  $bool_stevilo_segmentov = $false
  while($zanka){
      $uporabnikov_vnos = Read-Host - Prompt ""
      $lista_segmenti_IP = $uporabnikov_vnos.split(".")
      if($lista_segmenti_IP.Count -eq 4){$bool_stevilo_segmentov=$true}
      if ($uporabnikov_vnos.length -gt 6 -And $uporabnikov_vnos.length -lt 16){$bool_dolzina_niza = $true}
      if($zanka -eq $true){
      foreach ($posamezen_segment in $lista_segmenti_IP) {
        if ($posamezen_segment.length -gt 0 -And $posamezen_segment.length -lt 4 -And $posamezen_segment -as [int] -gt -1 -And $posamezen_segment -as [int] -lt 256){
          $bool_posamezen_segment=$true
        }
        else{$bool_posamezen_segment = $false
          break}
        }
      }
      if($bool_dolzina_niza -And $bool_posamezen_segment -And $bool_stevilo_segmentov){$zanka=$false}
    }
  return $uporabnikov_vnos
}

function Sprememba_IPv4 {
  #Sprememba statičnega IP-ja in izpis
  netsh interface ip set address $myAdapter static $IP $network_mask $network_GW
  #UPORABNIKOVA IZBIRA
  Write-Host "----------------------------"
  Write-Host "IP CONFIG"
  Write-Host "----------------------------"
  Write-Host "IP:   $IP" -ForegroundColor Green
  Write-Host "MASK: $network_mask" -ForegroundColor Green
  Write-Host "GW:   $network_GW" -ForegroundColor Green
  
  #clearamo vse nastavitve DNS-ja
  Set-DnsClientServerAddress -InterfaceAlias $myAdapter -ResetServerAddresses
      #DNS-ji
      if($DNS1){
        Write-Host "DNS1: $DNS1" -ForegroundColor Green
        if ($DNS2){Set-DnsClientServerAddress -InterfaceAlias $myAdapter -ServerAddresses $DNS1, $DNS2
          Write-Host "DNS2: $DNS2" -ForegroundColor Green}
        else{Set-DnsClientServerAddress -InterfaceAlias $myAdapter -ServerAddresses $DNS1}}
  
  Write-Host "----------------------------"
}

function Izbira_Adapterja{
  #Izberemo željeni adapter. Pregledamo vse adapterje na račuanlniku in uporabnika vprašamo katerega ši zeli imeti kot privzetega za spreminjanje.
  $uporabni_adapterji = Get-NetAdapter | Select-Object Name
  $User_prompt_2 = @()
  for ($i=0; $i -lt $uporabni_adapterji.Count; $i++) {
    $User_prompt_2 += [System.Management.Automation.Host.ChoiceDescription]("$($uporabni_adapterji[$i].Name) &$($i+1)")
  }
  $userChoice = $host.UI.PromptForChoice('', '', $User_prompt_2, 0) + 1
  $myAdapter = $($uporabni_adapterji[$userChoice-1].Name)
  return $myAdapter
}

function Izbira_DNS{
  #Če Želimo dodamo DNS-je.
  $confirmation_dns = Read-Host "Dodam tudi priljubljen DNS(y/n)?"
  if ($confirmation_dns -eq 'y') {
      Write-Host "DNS1:"
      $DNS1 = spremenljivka_network
      $confirmation_dns = Read-Host "Dodam tudi priljubljen DNS2(y/n)?"
      if($confirmation_dns){
      Write-Host "DNS2:"
      $DNS2 = spremenljivka_network
      }
      else {$DNS2 = $null}
  }
  else{
      $DNS1 = $null
      $DNS2 = $null
  }
  return $DNS1, $DNS2
}

#Preizkus če je bil program zagnan kot administrator.
Test-Administrator

#Inicializacija settings_IP datoteke, če datoteke ni nastavimo spremenljivko da uporabnika vrže direktno v nastavitve.
$settings_datoteka_ime = "settings_IP.xml"
$pot_do_temp = $env:TEMP
$settings_datoteka_pot = "$pot_do_temp\$settings_datoteka_ime"
$bool_settings_datoteka = Test-Path -Path $settings_datoteka_pot -PathType Leaf
$User_prompt_1 = 3

#Inicializacija glavnega menija.
$opcija_dhcp = New-Object System.Management.Automation.Host.ChoiceDescription "&DHCP","Vklopimo DHCP."
$opcija_auto_static = New-Object System.Management.Automation.Host.ChoiceDescription "&Auto-static IP","Potrebno je vpisati le IP, ostalolo določi avtomatsko."
$opcija_manual_static = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual-static IP","Ročno vpišemo celoten IP."
$settings = New-Object System.Management.Automation.Host.ChoiceDescription "&Nastavitve","Nastavitve"
$exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit","Zapustimo program."
while($true){
#Pogoj za settings datoteko.
if ($bool_settings_datoteka){
  #Beremo datoteko.
  $myAdapter, $default_mask, $GW_zadnji_del, $DNS1, $DNS2= Import-CliXml $settings_datoteka_pot
  #Galvni Meni.
  $options = [System.Management.Automation.Host.ChoiceDescription[]]($opcija_dhcp, $opcija_auto_static, $opcija_manual_static, $settings, $exit)
  $User_prompt_1 = $host.ui.PromptForChoice("SPREMEMBA IP-ja", "Izberite želeno opcijo.", $options, 0)
}
else{Write-Host "Pri prvem zagonu je potrebno vtipkati nekaj podatkov:"}
#Switch glede na uporabnikovo izbero glavnega menija.
switch ($User_prompt_1) {
    0{
        #Vklopimo DHCP
        Write-Host "Vklop DHCP-ja"
        netsh interface ip set address $myAdapter dhcp
        Write-Host "----------------------------"
        Write-Host "IP CONFIG"
        Write-Host "----------------------------"
        Write-Host "DHCP Vklopljen."-ForegroundColor Green
        Write-Host "----------------------------"
    }1{
        #Auto konfiguracija IP-ja. Uporabnik vpiše le IP.
        Write-Host "Auto-static IP"
        Write-Host "IP:"
        $IP = spremenljivka_network
        #Splitamo IP in spremenimo zadnji segment GW.
        $network_IP = $IP.split(".")
        $network_IP = $network_IP[0] +"."+ $network_IP[1] +"."+  $network_IP[2] + "."
        $network_GW = $network_IP+$GW_zadnji_del
        $network_IP  = $network_IP + "0"
        $network_mask = $default_mask
        #Funkcija
        Sprememba_IPv4
    }2{
        #Izberemo adapter
        $myAdapter = Izbira_Adapterja
        #Uproabnik določi IP v celoti
        Write-Host "Popolna nastavitev IP-ja"
        Write-Host "IP:"
        $IP = spremenljivka_network
        Write-Host "Maska:"
        $network_mask = spremenljivka_network
        Write-Host "Privzeti_prehod:"
        $network_GW = spremenljivka_network
        $DNS1, $DNS2 = Izbira_DNS
        #Funkcija
        Sprememba_IPv4
    }
    3{
        #Sprememba Uporabniških nastavitev
        Write-Host "NASTAVITVE"
        Write-Host "Izberite željeni adapter"
        #Izberemo adapter
        $myAdapter = Izbira_Adapterja
        #Določimo masko.
        Write-Host "Maska:"
        $network_mask = spremenljivka_network
        #Izberemo zadnji segment privzetega prehoda, številka ne sme biti višja 254 in manjša od ena, število mest pa mora obsegati med 1 in 3 mesti. 
        do {
          $network_GW = Read-Host -Prompt "Običajen zadnji del privzetega prehoda s številko (običajno 1 ali 254)"
          $value = $network_GW -as [Double]
          $ok = $NULL -ne $value 
          if ( -not $ok ) { write-host "Vrednost mora biti zapisana s številko" }
          if ($network_GW.length -gt 3 -Or $network_GW -gt 254 -Or $network_GW -lt 1) {Write-Output "Neveljavna številka, vnesi jo ponovno."
          $ok=$false
            }
        }
        until ( $ok )
        $DNS1, $DNS2 = Izbira_DNS
        #Vse uporabnikove želje zapišemo v datoteko.
        $myAdapter, $network_mask, $network_GW, $DNS1, $DNS2 | Export-CliXml $settings_datoteka_pot
    }
    4{
      #Zapremo program.
      exit
    }
  }
}
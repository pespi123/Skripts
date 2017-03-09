<#
Autor: Nemanja Bocokic
Datum: 03.01.2017
Funktion: Legt einen SOAP-Request ab (mit Credentials), speichert diesen in einer Datei und Kontrolliert den String in der Datei schlussendlich

Dieses Plugin wird durch den NSClient (NRPE) ausgeführt und muss auf der Zielmaschine lokal gespeichert sein!
State 0 = OK
State 2 = Critical

####################################### Example #######################################
$url = 'http://srvdevnst06.alpha-solutions.ch:7252/ALPHA_DEV_9_00_00_CH/WS/Alpha%20Solutions%20AG/Codeunit/WSTEST'
$username = "Nav-service"
$password = "`$Braunholz"
$string_answer = "HelloNemanja"

Damit bei der Antwort "HelloNemanja" kommt muss der soap-String bei der Variable angepasst werden (beachte Nemanja):
$soap = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wst="urn:microsoft-dynamics-schemas/codeunit/WSTEST">
   <soapenv:Header/>
   <soapenv:Body>
      <wst:HelloWorld>
         <wst:myName>Nemanja</wst:myName>
      </wst:HelloWorld>
   </soapenv:Body>
</soapenv:Envelope>
'@
####################################################################################
##

#>

## --------------------- Parameter ---------------------

$url = 'http://srvdevnst06.alpha-solutions.ch:7252/ALPHA_DEV_9_00_00_CH/WS/Alpha%20Solutions%20AG/Codeunit/WSTEST'
$username = "Nav-service"
$password = "`$Braunholz"
$string_answer = "HelloNemanja"

# Der Soap Request (kann aus SoapUI herauskopiert werden) | Beachte das Beispiel
$soap = [xml]@'
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wst="urn:microsoft-dynamics-schemas/codeunit/WSTEST">
   <soapenv:Header/>
   <soapenv:Body>
      <wst:HelloWorld>
         <wst:myName>Nemanja</wst:myName>
      </wst:HelloWorld>
   </soapenv:Body>
</soapenv:Envelope>
'@

# -----------------------------------------------------

function Execute-SOAPRequest 
( 
        [Xml]    $SOAPRequest, 
        [String] $URL 
) 
{ 

        $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
        $soapWebRequest.Credentials = new-object System.Net.NetworkCredential($username,$password)
        $soapWebRequest.Headers.Add("SOAPAction","`"$url`"")
        $soapWebRequest.Headers.Add("Credentials", $login)
        $soapWebRequest.ContentType = "text/xml;charset=`"utf-8`"" 
        $soapWebRequest.Method      = "POST" 
        
        $requestStream = $soapWebRequest.GetRequestStream() 
        $SOAPRequest.Save($requestStream) 
        $requestStream.Close() 
        
        $resp = $soapWebRequest.GetResponse() 
        $responseStream = $resp.GetResponseStream() 
        $soapReader = [System.IO.StreamReader]($responseStream) 
        $ReturnXml = [Xml] $soapReader.ReadToEnd() 
        $responseStream.Close() 
        return $ReturnXml 

}

$ret = Execute-SOAPRequest $soap $url; $ret | Export-Clixml  "results.xml";

# Suche nach dem "OK" String in der Datei
$searchresults = Get-ChildItem "results.xml" | select-string -pattern "$string_answer" | Select-Object -Unique Path


if ($searchresults -eq $null) {
    $state = 2
    $statetext = "SOAP-Returnwert falsch oder nicht erhalten!"   
} else {
    $state = 0
    $statetext = "SOAP-Returnwert OK"
}
Write-Host "$statetext | 'State'=$state;2:00:00"
exit $state
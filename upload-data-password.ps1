# Ruta del archivo CSV
$csvPath = "C:\ResultadosContrasenas.csv"
$token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjgwMDAvYXBpL2xvZ2luIiwiaWF0IjoxNzIyOTYwMjIyLCJleHAiOjE3MjI5NjM4MjIsIm5iZiI6MTcyMjk2MDIyMiwianRpIjoiWjNNenBqdmRDSG5ocE85UiIsInN1YiI6IjEiLCJwcnYiOiIyM2JkNWM4OTQ5ZjYwMGFkYjM5ZTcwMWM0MDA4NzJkYjdhNTk3NmY3In0.XU0lh3oxqvKxdoRLkvuooX5QT-h7Ek_smYp_XBfuB1A"

$hostname = (Get-ComputerInfo).CsName
$hostnameExists = $false
$idHostname = $null
$idFile = $null


# # Definir el endpoint
$endpointHostname = "http://localhost:8000/api/hostname"
$endpointFiles = "http://localhost:8000/api/files"
$endpointKeyFiles = "http://localhost:8000/api/keyFiles"

$responseHostName = Invoke-RestMethod -Uri $endpointHostname -Method Get -Headers @{ Authorization = "Bearer $token" }


foreach ($item in $responseHostName.data) {
    if ($item.name -eq $hostname) {
        $hostnameExists = $true
        $idHostname = $item.id
        break
    }
}

# Verificar si el hostname existe en la respuesta
if (!$hostnameExists) {
    # Si el hostname no existe, realizar la petición POST
    $body = @{
        name = $hostname
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $endpointHostname -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"
    $idHostname = $response.data.id
}


# # Leer el contenido del archivo CSV
$csvContent = Get-Content -Path $csvPath

# # Array para almacenar las filas
$filasArray = @()

# Iterar sobre cada línea del contenido del CSV comenzando desde el índice 1
for ($i = 1; $i -lt $csvContent.Length; $i++) {
    $linea = $csvContent[$i]
    
    # Verificar si la línea ya tiene un asterisco al final
    if ($linea -match '\*$') {
        continue
    }
    Write-Output "Sin *"

    # Dividir la línea en campos usando solo las últimas dos comas como delimitadores
    $posicionesComas = ($linea | Select-String -Pattern "," -AllMatches).Matches | Select-Object -Last 2

    if ($posicionesComas.Count -lt 2) {
        $campos = $linea -split ','
    } else {
        $penultimaPos = $posicionesComas[-2].Index

        $parte1 = $linea.Substring(0, $penultimaPos)
        $parte2 = $linea.Substring($penultimaPos + 1)

        $camposParte2 = $parte2 -split ','

        $campos = @($parte1) + $camposParte2
    }

    # Eliminar las comillas de cada campo
    $campos = $campos -replace '"', ''

    # Convertir los campos en un array y agregarlo al array principal
    $filasArray += ,@($campos)
    
    Write-Output $filasArray[0][0]
    
    $endpointFilesConId = "http://localhost:8000/api/getFile/$idHostname"
    $responseFileValidate = Invoke-RestMethod -Uri $endpointFilesConId -Method Get -Headers @{ Authorization = "Bearer $token" }
    $existDataFile = $responseFileValidate.data | Where-Object { $_.computer_path -eq $filasArray[0][0] }
    # Write-Output $existDataFile
    Write-Output $existDataFile.computer_path
   
    # Verificar si $responseFileValidate.data no está vacío
    if ($existDataFile) {
        $body = @{
            name_key = $filasArray[0][1]
            line = $filasArray[0][2]
            id_file = $existDataFile.id
        } | ConvertTo-Json

        $responseFiles = Invoke-RestMethod -Uri $endpointKeyFiles -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"
    } else {
        $fileBytes = [System.IO.File]::ReadAllBytes($filasArray[0][0])
        
        # Convertir los bytes del archivo a Base64
        $base64Content = [Convert]::ToBase64String($fileBytes)
        
        # Write-Output $base64Content
        # break
        # Crear el cuerpo de la petición para guardar archivo con el hostname asociado
        $body = @{
            computer_path = $filasArray[0][0]
            server_path = $base64Content
            id_hostname = $idHostname
        } | ConvertTo-Json

        $responseFiles = Invoke-RestMethod -Uri $endpointFiles -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"

        $idFile = $responseFiles.data.id
    
        # Crear cuerpo para guardar nombre de la palabra clave encontrada en su respectiva linea y archivo asociado
        $body = @{
            name_key = $filasArray[0][1]
            line = $filasArray[0][2]
            id_file = $idFile
        } | ConvertTo-Json
    
        # Write-Output $body
        $response = Invoke-RestMethod -Uri $endpointKeyFiles -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"
    }

    # Reiniciar $filasArray a vacío
    $filasArray = @()
    Write-Output $response

    # Agregar un asterisco al final de la línea original si no es la última línea
    $csvContent[$i] = "$linea,*"
}

# Guardar el contenido modificado en el archivo CSV
$csvContent | Set-Content -Path $csvPath
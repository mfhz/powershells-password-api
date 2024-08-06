# Ruta de la carpeta donde se realizará la búsqueda
$carpeta = "C:\"

# Lista de rutas a excluir
$exclusiones = @(
    "C:\PerfLogs",
    "C:\Program Files (x86)",
    "C:\Program Files",
    "C:\Windows",
    "C:\xampp",
    "C:\Oracle",
    "C:\PowerBuilder",
    "C:\ProgramData",
    "C:\PowerBuilder",
    "C:\Users\*\.vscode",
    "C:\Users\*\ .vscode"
)

# Lista para almacenar las rutas y palabras encontradas de archivos con posibles contraseñas
$resultados = New-Object System.Collections.Generic.List[PSCustomObject]

# Palabras a buscar
$palabrasClave = @("contraseña:", "pwd:", "password:", "clave:", "contrasena:", "credential:", "pass:", "key:", "credential:","contraseña=", "pwd=", "password=", "clave=", "contrasena=", "credential=", "pass=", "key=", "credential=", "contraseña", "pwd", "password", "clave", "contrasena", "credential", "pass", "key", "credential")

# Función para verificar si una ruta está en la lista de exclusiones
function EstaEnExclusiones($ruta, $exclusiones) {
    foreach ($exclusion in $exclusiones) {
        if ($ruta -like "$exclusion*") {
            return $true
        }
    }
    return $false
}

# Función recursiva para obtener archivos con manejo de excepciones
function ObtenerArchivos($ruta) {
    $archivos = @()
    try {
        $items = Get-ChildItem -Path $ruta -ErrorAction Stop
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if (-not (EstaEnExclusiones $item.FullName $exclusiones)) {
                    $archivos += ObtenerArchivos $item.FullName
                }
            } else {
                if ($item.Extension -in @('.txt', '.csv', '.dll', '.xml', '.html', '.ps1', '.bat', '.ini') -and -not (EstaEnExclusiones $item.FullName $exclusiones)) {
                    $archivos += $item
                }
            }
        }
    } catch {
        Write-Output "Error al acceder a la ruta: $ruta - $_"
    }
    return $archivos
}

# Obtener todos los archivos aplicando exclusiones
$archivos = ObtenerArchivos $carpeta

# Función para buscar palabras clave en los archivos
function BuscarPalabrasClave($archivo) {
    try {
        $contenido = Get-Content -Path $archivo.FullName -ErrorAction Stop
        for ($i = 0; $i -lt $contenido.Length; $i++) {
            $linea = $contenido[$i]
            foreach ($palabra in $palabrasClave) {
                if ($linea -match $palabra) {
                    $resultados.Add([PSCustomObject]@{
                        Ruta = $archivo.FullName
                        PalabraClave = $palabra
                        Linea = $i + 1
                    })
                }
            }
        }
    } catch {
        Write-Output "No se pudo leer el archivo $($archivo.FullName): $_"
    }
}

# Buscar palabras clave en cada archivo
foreach ($archivo in $archivos) {
    BuscarPalabrasClave $archivo
}

# Exporta los resultados a un archivo CSV
$resultados | Export-Csv -Path "C:\ResultadosContrasenas.csv" -NoTypeInformation

Write-Output "Busqueda completada. Resultados exportados a 'C:\ResultadosContrasenas.csv'"
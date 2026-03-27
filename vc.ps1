# Имя ключа реестра для хранения данных
$RegKey = "HKCU:\Software\MyScripts\VideoCleanup"
$RegValueName = "FilesToDelete"

# 1. Создаём ключ, если его нет (не вызывает ошибку, если уже существует)
if (!(Test-Path $RegKey)) {
    New-Item -Path $RegKey -Force | Out-Null
}

# 2. Читаем значение из реестра (ожидаем REG_MULTI_SZ или REG_SZ)
$RegistryValue = Get-ItemProperty -Path $RegKey -Name $RegValueName -ErrorAction SilentlyContinue
$FilesToDelete = @()
if ($RegistryValue) {
    $RawValue = $RegistryValue.$RegValueName
    if ($RawValue -is [array]) {
        $FilesToDelete = $RawValue | Where-Object { $_ } # Фильтруем пустые строки
    } else {
        # Если это одна строка, проверяем, не пустая ли она
        if ($RawValue) {
            $FilesToDelete = @($RawValue)
        }
    }
}

# 3. Обходим все пути и удаляем файлы в корзину
$Shell = New-Object -ComObject Shell.Application

foreach ($File in $FilesToDelete) {
    $File = $File.Trim()
    if ($File -and (Test-Path $File -PathType Leaf)) {
        try {
            $ShellItem = $Shell.NameSpace(0).ParseName($File)
            $ShellItem.InvokeVerb("delete")
        }
        catch {
            # Игнорируем ошибки
        }
    }
}

# 4. Очищаем значение в реестре (даже если удаление не удалось)
try {
    Remove-ItemProperty -Path $RegKey -Name $RegValueName -ErrorAction Stop
}
catch {
    # Если параметр уже отсутствует, всё равно продолжаем
}

# 5. Ищем все приложения с именем MPC-HC
$MpcProcesses = Get-Process -Name "mpc-be", "mpc-be_x64" -ErrorAction SilentlyContinue

# 6. Для каждого процесса читаем заголовок окна и добавляем в массив
$TitlesToWrite = @()
foreach ($Proc in $MpcProcesses) {
    try {
        $WindowTitle = $Proc.MainWindowTitle
        if ($WindowTitle) {
            $TitlesToWrite += $WindowTitle
        }
    }
    catch {
        # Игнорируем ошибки
    }
}

# 7. Записываем новые заголовки в реестр (если есть что записать)
if ($TitlesToWrite.Count -gt 0) {
    try {
        Set-ItemProperty -Path $RegKey -Name $RegValueName -Value $TitlesToWrite -Type MultiString -Force
    }
    catch {
        # Игнорируем ошибки записи
    }
}
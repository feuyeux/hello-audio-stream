# Kill process using port 8080
$port = 8080

Write-Host "Checking for processes using port $port..." -ForegroundColor Yellow

# Find the process using the port
$connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue

if ($connection) {
    $processId = $connection.OwningProcess
    
    # Skip system processes (PID 0, 4)
    if ($processId -le 4) {
        Write-Host "Port is used by system process (PID: $processId), cannot kill" -ForegroundColor Red
        exit 1
    }
    
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    
    if ($process) {
        Write-Host "Found process: $($process.ProcessName) (PID: $processId)" -ForegroundColor Cyan
        Write-Host "Killing process..." -ForegroundColor Red
        
        Stop-Process -Id $processId -Force
        
        Start-Sleep -Milliseconds 500
        
        # Verify the process is killed
        $stillRunning = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($stillRunning) {
            Write-Host "Failed to kill process" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Process killed successfully" -ForegroundColor Green
        }
    } else {
        Write-Host "Could not find process details" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "No process is using port $port" -ForegroundColor Green
}

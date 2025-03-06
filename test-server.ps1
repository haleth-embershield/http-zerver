# HTTP Server Load Test Script
# This script makes multiple requests to the server and measures performance

param(
    [int]$RequestCount = 1000,
    [string]$Url = "http://localhost:8000/",
    [string]$OutputFile = "test-results.txt",
    [int]$Concurrent = 10,
    [switch]$DownloadFile
)

Write-Host "HTTP Server Load Test"
Write-Host "====================="
Write-Host "URL: $Url"
Write-Host "Number of requests: $RequestCount"
Write-Host "Concurrent requests: $Concurrent"
Write-Host "Output file: $OutputFile"
Write-Host ""

# Create or clear the output file
"HTTP Server Load Test Results - $(Get-Date)" | Out-File -FilePath $OutputFile
"URL: $Url" | Out-File -FilePath $OutputFile -Append
"Requests: $RequestCount" | Out-File -FilePath $OutputFile -Append
"Concurrent: $Concurrent" | Out-File -FilePath $OutputFile -Append
"" | Out-File -FilePath $OutputFile -Append

# Function to make a single request
function Make-Request {
    param (
        [int]$RequestNumber,
        [string]$TargetUrl
    )
    
    $startTime = Get-Date
    
    try {
        if ($DownloadFile) {
            # Use -o NUL to discard output but still download the file
            curl.exe -s -o NUL $TargetUrl
        } else {
            # Use GET request but discard the output
            curl.exe -s -o NUL $TargetUrl
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        return @{
            RequestNumber = $RequestNumber
            Success = $true
            Duration = $duration
            Error = $null
        }
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        return @{
            RequestNumber = $RequestNumber
            Success = $false
            Duration = $duration
            Error = $_.Exception.Message
        }
    }
}

# Start timing
$totalStartTime = Get-Date

# Track statistics
$successCount = 0
$failureCount = 0
$totalDuration = 0
$minDuration = [double]::MaxValue
$maxDuration = 0

# Process requests in batches for concurrency
for ($i = 0; $i -lt $RequestCount; $i += $Concurrent) {
    $batchSize = [Math]::Min($Concurrent, $RequestCount - $i)
    $jobs = @()
    
    # Start concurrent requests
    for ($j = 0; $j -lt $batchSize; $j++) {
        $requestNumber = $i + $j + 1
        $progress = [Math]::Round(($requestNumber / $RequestCount) * 100, 1)
        Write-Progress -Activity "Making HTTP Requests" -Status "$requestNumber of $RequestCount ($progress%)" -PercentComplete $progress
        
        $jobs += Start-Job -ScriptBlock {
            param($num, $url, $downloadFile)
            
            # Define the function inside the job
            function Make-Request {
                param (
                    [int]$RequestNumber,
                    [string]$TargetUrl
                )
                
                $startTime = Get-Date
                
                try {
                    if ($downloadFile) {
                        # Use -o NUL to discard output but still download the file
                        curl.exe -s -o NUL $TargetUrl
                    } else {
                        # Use GET request but discard the output
                        curl.exe -s -o NUL $TargetUrl
                    }
                    
                    $endTime = Get-Date
                    $duration = ($endTime - $startTime).TotalMilliseconds
                    
                    return @{
                        RequestNumber = $RequestNumber
                        Success = $true
                        Duration = $duration
                        Error = $null
                    }
                } catch {
                    $endTime = Get-Date
                    $duration = ($endTime - $startTime).TotalMilliseconds
                    
                    return @{
                        RequestNumber = $RequestNumber
                        Success = $false
                        Duration = $duration
                        Error = $_.Exception.Message
                    }
                }
            }
            
            # Call the function
            Make-Request -RequestNumber $num -TargetUrl $url
        } -ArgumentList $requestNumber, $Url, $DownloadFile
    }
    
    # Wait for all jobs to complete
    $results = $jobs | Wait-Job | Receive-Job
    
    # Process results
    foreach ($result in $results) {
        if ($result.Success) {
            $successCount++
            $totalDuration += $result.Duration
            
            if ($result.Duration -lt $minDuration) {
                $minDuration = $result.Duration
            }
            
            if ($result.Duration -gt $maxDuration) {
                $maxDuration = $result.Duration
            }
            
            "Request $($result.RequestNumber): Success - $($result.Duration) ms" | Out-File -FilePath $OutputFile -Append
        } else {
            $failureCount++
            "Request $($result.RequestNumber): Failed - $($result.Error)" | Out-File -FilePath $OutputFile -Append
        }
    }
    
    # Clean up jobs
    $jobs | Remove-Job
    
    # Every 100 requests, show a summary
    if (($i + $batchSize) % 100 -eq 0 -or ($i + $batchSize) -eq $RequestCount) {
        $completedRequests = $i + $batchSize
        $avgDuration = if ($successCount -gt 0) { $totalDuration / $successCount } else { 0 }
        
        Write-Host "Completed $completedRequests of $RequestCount requests"
        Write-Host "Success: $successCount, Failures: $failureCount"
        Write-Host "Average response time: $([Math]::Round($avgDuration, 2)) ms"
        Write-Host ""
    }
}

# Calculate final statistics
$totalEndTime = Get-Date
$totalElapsedTime = ($totalEndTime - $totalStartTime).TotalSeconds
$requestsPerSecond = $RequestCount / $totalElapsedTime
$avgDuration = if ($successCount -gt 0) { $totalDuration / $successCount } else { 0 }

# Output final results
Write-Host "Test completed in $([Math]::Round($totalElapsedTime, 2)) seconds"
Write-Host "Requests per second: $([Math]::Round($requestsPerSecond, 2))"
Write-Host "Success rate: $([Math]::Round(($successCount / $RequestCount) * 100, 2))%"
Write-Host "Average response time: $([Math]::Round($avgDuration, 2)) ms"
Write-Host "Min response time: $([Math]::Round($minDuration, 2)) ms"
Write-Host "Max response time: $([Math]::Round($maxDuration, 2)) ms"

# Save final statistics to the output file
"" | Out-File -FilePath $OutputFile -Append
"Summary" | Out-File -FilePath $OutputFile -Append
"=======" | Out-File -FilePath $OutputFile -Append
"Total time: $([Math]::Round($totalElapsedTime, 2)) seconds" | Out-File -FilePath $OutputFile -Append
"Requests per second: $([Math]::Round($requestsPerSecond, 2))" | Out-File -FilePath $OutputFile -Append
"Success rate: $([Math]::Round(($successCount / $RequestCount) * 100, 2))%" | Out-File -FilePath $OutputFile -Append
"Average response time: $([Math]::Round($avgDuration, 2)) ms" | Out-File -FilePath $OutputFile -Append
"Min response time: $([Math]::Round($minDuration, 2)) ms" | Out-File -FilePath $OutputFile -Append
"Max response time: $([Math]::Round($maxDuration, 2)) ms" | Out-File -FilePath $OutputFile -Append

Write-Host ""
Write-Host "Results saved to $OutputFile" 
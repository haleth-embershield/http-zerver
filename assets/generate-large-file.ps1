# Generate a large test file for performance testing
param(
    [string]$OutputFile = "largefile.bin",
    [int]$SizeMB = 10
)

Write-Host "Generating test file: $OutputFile"
Write-Host "Size: $SizeMB MB"

$buffer = New-Object byte[] (1024 * 1024) # 1MB buffer
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider

# Create or overwrite the file
$fileStream = [System.IO.File]::Create($OutputFile)

try {
    for ($i = 0; $i -lt $SizeMB; $i++) {
        # Fill the buffer with random data
        $rng.GetBytes($buffer)
        
        # Write the buffer to the file
        $fileStream.Write($buffer, 0, $buffer.Length)
        
        # Show progress
        $progress = [Math]::Round((($i + 1) / $SizeMB) * 100)
        Write-Progress -Activity "Generating large file" -Status "$($i + 1) of $SizeMB MB written" -PercentComplete $progress
    }
    
    Write-Host "File generated successfully: $OutputFile"
    Write-Host "Size: $SizeMB MB"
} finally {
    # Make sure to close the file
    $fileStream.Close()
    $rng.Dispose()
} 
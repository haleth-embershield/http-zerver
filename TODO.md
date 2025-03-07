- MacOS port
- Cleanup Example and move to readme, delete files




getting this error VERY randomly on other projects, intermittent, havent been able to reproduce realiabily

```
PS C:\Users\hotschmoe\Documents\GitHub\zig-wasm-template> zig build run
Setting up http-zerver...
Cloning http-zerver repository...
Building http-zerver...
Copying http-zerver executable to root directory...
Cleaning up...
Setup complete! http-zerver has been copied to the root directory.

Starting HTTP Zerver...
Version 2025.03.06 (Windows, Built: 2025-03-07)
Listening at http://localhost:8000
Serving directory: www

GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
thread 18744 panic: attempt to cast negative value to unsigned integer
???:?:?: 0xcfd30f in ??? (http-zerver.exe)
???:?:?: 0xcc8850 in ??? (http-zerver.exe)
???:?:?: 0xcc2956 in ??? (http-zerver.exe)
???:?:?: 0xcc1f46 in ??? (http-zerver.exe)
???:?:?: 0xcc2e69 in ??? (http-zerver.exe)
???:?:?: 0xcc353c in ??? (http-zerver.exe)
???:?:?: 0x7ffbb961dbe6 in ??? (KERNEL32.DLL)
???:?:?: 0x7ffbba5e5a4b in ??? (ntdll.dll)
run
└─ run http-zerver.exe failure
error: the following command exited with error code 3:
http-zerver.exe --port 8000 --dir www
Build Summary: 8/10 steps succeeded; 1 failed (disable with --summary none)
run transitive failure
└─ run http-zerver.exe failure
error: the following build command failed with exit code 1:
C:\Users\hotschmoe\Documents\GitHub\zig-wasm-template\.zig-cache\o\4b473be0653e5d22e5f22a2e859ad865\build.exe C:\Users\hotschmoe\AppData\Local\Microsoft\WinGet\Packages\zig.zig_Microsoft.Winget.Source_8wekyb3d8bbwe\zig-windows-x86_64-0.13.0\zig.exe C:\Users\hotschmoe\Documents\GitHub\zig-wasm-template C:\Users\hotschmoe\Documents\GitHub\zig-wasm-template\.zig-cache C:\Users\hotschmoe\AppData\Local\zig --seed 0xcda235a4 -Z00995b5e7548332d run
```

spamming ctrl-F5 i can get it to reproduce

```
PS C:\Users\hotschmoe\Documents\GitHub\zig-wasm-template> zig build run
http-zerver detected, skipping setup...

Starting HTTP Zerver...
Version 2025.03.06 (Windows, Built: 2025-03-07)
Listening at http://localhost:8000
Serving directory: www

GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
GET '/favicon.ico' --> Content-Type: application/octet-stream --> HTTP/1.1 200 OK
GET '/example.wasm' --> Content-Type: application/wasm --> HTTP/1.1 200 OK
GET '/' --> Content-Type: text/html --> HTTP/1.1 200 OK
thread 8784 panic: attempt to cast negative value to unsigned integer
???:?:?: 0xcfd30f in ??? (http-zerver.exe)
???:?:?: 0xcc8850 in ??? (http-zerver.exe)
???:?:?: 0xcc27a2 in ??? (http-zerver.exe)
???:?:?: 0xcc1f46 in ??? (http-zerver.exe)
???:?:?: 0xcc2e69 in ??? (http-zerver.exe)
???:?:?: 0xcc353c in ??? (http-zerver.exe)
???:?:?: 0x7ffbb961dbe6 in ??? (KERNEL32.DLL)
???:?:?: 0x7ffbba5e5a4b in ??? (ntdll.dll)
run
└─ run http-zerver.exe failure
error: the following command exited with error code 3:
http-zerver.exe --port 8000 --dir www
Build Summary: 8/10 steps succeeded; 1 failed (disable with --summary none)
run transitive failure
└─ run http-zerver.exe failure
error: the following build command failed with exit code 1:
```
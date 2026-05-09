@echo off
cd /d "%~dp0"
cls

echo ===========================================================
echo   BAT CHAU: TRINH CHAY KIEM THU CHI MUC (INDEX BENCHMARK)
echo   SQL SERVER VS CASSANDRA
echo ===========================================================
echo.

:: 1. Chạy SQL Server
echo [1/2] Dang thuc thi cac kich ban tren SQL Server...
docker exec -i sql-server-db /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P SuperStrong@Password2026 -C -d BankDB < "test_indexing_sqlserver.sql" > Result_SQLServer.txt
echo Done! Ket qua luu tai: Result_SQLServer.txt
echo.

:: 2. Chạy Cassandra
echo [2/2] Dang thuc thi cac kich ban tren Cassandra (Co the mat 1-2 phut de xay View/Index)...
:: ĐÃ THÊM: --request-timeout=300 để cqlsh không bị ngắt ngang khi xử lý 1 triệu dòng
docker exec -i cassandra-db cqlsh --request-timeout=300 < "test_indexing_cassandra.cql" > Result_Cassandra_Raw.txt 2>&1

:: Dung PowerShell de loc rac va lay dung thoi gian (ms)
echo Dang don dep file log cua Cassandra...
powershell -Command "$names = @('KICH BAN 1: Point Lookup', 'KICH BAN 2: Table Scan', 'KICH BAN 3: Secondary Index (2i)', 'KICH BAN 4: Range Query (SAI)', 'KICH BAN 5a: Thoi gian KHOI TAO View (Chi phi an)', 'KICH BAN 5b: Thoi gian TRUY VAN qua View'); $i=0; Write-Output '======================================================='; Write-Output 'KET QUA CASSANDRA BENCHMARK (DA TINH CHI PHI AN)'; Write-Output '======================================================='; Get-Content Result_Cassandra_Raw.txt | Select-String 'Request complete' | ForEach-Object { if ($i -lt 6) { $t = ($_ -split '\|')[3].Trim(); $ms = [math]::Round([double]$t / 1000, 2); Write-Output ($names[$i] + ' = ' + $ms + ' ms'); Write-Output '-------------------------------------------------------'; $i++ } }; Write-Output '======================================================='" > Result_Cassandra.txt

echo Done! Ket qua sach se luu tai: Result_Cassandra.txt
echo.
pause
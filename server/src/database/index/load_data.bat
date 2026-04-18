@echo off
cd /d "%~dp0"
cls

echo ===========================================================
echo   TIEN TRINH NAP DU LIEU (SQL SERVER VA CASSANDRA)
echo ===========================================================
echo.

:: SQL
echo [1/2] DANG NAP DU LIEU VAO SQL SERVER...
echo Vui long cho (co the mat vai chuc giay)...
docker exec -i sql-server-db /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P SuperStrong@Password2026 -C < "insert_sqlserver.sql"
echo.
echo =^> XONG SQL SERVER!
echo -------------------------------------------------------
echo.

:: Cassandra
echo [2/2] DANG NAP DU LIEU VAO CASSANDRA...
echo Dang xoa Keyspace cu va xay dung lai cau truc...
echo Dang thuc hien lenh COPY de import file CSV...
echo Vui long kien nhan cho doi (co the mat 1-3 phut)...
docker exec -i cassandra-db cqlsh < "insert_cassandra.cql"
echo.
echo =^> XONG CASSANDRA!
echo.

echo ===========================================================
echo HOAN TAT NAP DU LIEU CHO CA 2 HE THONG!
echo ===========================================================
pause
@echo off
:: Define as variáveis para facilitar a manutenção
set "ORIGEM=C:\home\admin\www\fimatheDailyChannels\Indicators\FimatheChannels\FimatheDailyChannels.mq5"
set "DESTINO_PASTA=C:\Users\wayre\Aplicativos\MetaTrader5\MQL5\Indicators\Fimathe"
set "METAEDITOR_PATH=C:\Users\wayre\Aplicativos\MetaTrader5\metaeditor64.exe"

echo.
echo 📜 Iniciando o script de compilacao MQL5...

:: 1. Cria o diretório de destino se ele não existir
if not exist "%DESTINO_PASTA%" (
    echo Criando pasta de destino: "%DESTINO_PASTA%"
    mkdir "%DESTINO_PASTA%"
)

:: Extrai apenas o nome do arquivo da ORIGEM
for %%f in ("%ORIGEM%") do set "NOME_ARQUIVO=%%~nxf"

:: Define o caminho completo do arquivo no destino
set "DESTINO_ARQUIVO=%DESTINO_PASTA%\%NOME_ARQUIVO%"

:: 2. Copia o arquivo .mq5 para o destino
echo.
echo 📥 Copiando arquivo de origem para destino...
copy /Y "%ORIGEM%" "%DESTINO_ARQUIVO%"

if errorlevel 1 (
    echo ❌ ERRO na copia do arquivo. Saindo.
    goto :eof
)
echo ✅ Copia concluida.

:: 3. Executa a compilação usando o MetaEditor
echo.
echo 🛠️ Iniciando a compilacao com MetaEditor...
:: O MetaEditor precisa estar na pasta C:\Users\wayre\Aplicativos\MetaTrader5
start "" /wait "%METAEDITOR_PATH%" /compile:"%DESTINO_ARQUIVO%" /log

:: O comando acima executa o MetaEditor, passa o arquivo para compilar (/compile:),
:: e espera (start /wait) o editor fechar, o que geralmente acontece
:: apos a compilacao se for usado o argumento /compile.

:: 4. Log de Conclusão Final
echo.
echo =======================================================
echo 🎉 COMPILACAO MQL5 CONCLUIDA COM SUCESSO!
echo O arquivo "%NOME_ARQUIVO%" foi copiado e compilado.
echo =======================================================
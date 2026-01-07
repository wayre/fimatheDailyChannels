#!/bin/bash

# --- Variáveis ---
SOURCE_BASE_INDICATOR="./Indicators"
DEST_BASE_INDICATOR="/www/mql/MT5-folder/MQL5/Indicators"
FOLDER_INDICATOR="FimatheChannels"

# CAMINHO PARA O METAEDITOR (AJUSTE PARA O SEU CAMINHO NO WINDOWS)
# Geralmente fica dentro da pasta de instalação do MT5
METAEDITOR_EXE="/mnt/c/MT5/metaeditor64.exe"

# --- 1. Sincronização dos Experts ---
# echo "▶️ Sincronizando Experts..."
# EXPERT_SOURCE="${SOURCE_BASE}/Experts/RoboFimathe"
# EXPERT_DEST="${DEST_BASE}/Experts/RoboFimathe"
# mkdir -p "${EXPERT_DEST}"
# cp -rv "${EXPERT_SOURCE}/"* "${EXPERT_DEST}/"

# --- 2. Sincronização dos Indicadores ---
echo "▶️ Sincronizando Indicators..."
INDICATOR_SOURCE="${SOURCE_BASE_INDICATOR}/${FOLDER_INDICATOR}"
INDICATOR_DEST="${DEST_BASE_INDICATOR}/${FOLDER_INDICATOR}"
mkdir -p "${INDICATOR_DEST}"

echo "⚙️ Copiando Indicador.."
cp -rv "${INDICATOR_SOURCE}/"* "${INDICATOR_DEST}/"

# --- 3. COMPILAÇÃO ---

# Função para compilar via MetaEditor Windows
compile_mql5() {
    local linux_path=$1
    # Converte o caminho Linux para Windows
    local win_path=$(wslpath -w "$linux_path")
    
    echo "🔨 Compilando: $win_path"
    
    # Chama o executável do Windows
    # /log gera um arquivo .log com erros, se houver.
    "$METAEDITOR_EXE" /compile:"$win_path" /log
}

# compile_mql5 "${INDICATOR_DEST}/FimatheDailyChannels.mq5"
# ls -l "${INDICATOR_DEST}/"
# cat "${INDICATOR_DEST}/FimatheDailyChannels.log"

# Se quiser compilar o Robô também:
# compile_mql5 "${EXPERT_DEST}/SeuRobo.mq5"

# echo "✅ Sincronização e tentativa de compilação concluídas!"
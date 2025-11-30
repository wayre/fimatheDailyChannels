#!/bin/bash

# Este script sincroniza os arquivos do projeto RoboFimathe
# (Experts e Indicadores) para a pasta de instalação do MT5/Wine.

# clear;
# --- Variáveis ---
# Base do seu projeto
SOURCE_BASE="/www/mql/fimathe/MQL5"
# Base da pasta de instalação do MT5/Wine
DEST_BASE="/www/mql/MT5-folder/MQL5"

# --- 1. Sincronização dos Experts ---
echo "▶️ Sincronizando Experts/RoboFimathe..."
EXPERT_SOURCE="${SOURCE_BASE}/Experts/RoboFimathe"
EXPERT_DEST="${DEST_BASE}/Experts/RoboFimathe"

# Cria o diretório de destino
mkdir -p "${EXPERT_DEST}"

# Copia todos os arquivos e pastas da origem para o destino
# O '*' garante que o conteúdo da pasta seja copiado, e não a pasta em si.
cp -r "${EXPERT_SOURCE}/"* "${EXPERT_DEST}/"

# --- 2. Sincronização dos Indicadores (FimatheLevels) ---
echo "▶️ Sincronizando Indicators/FimatheChannels..."
INDICATOR_SOURCE="${SOURCE_BASE}/Indicators/FimatheChannels"
INDICATOR_DEST="${DEST_BASE}/Indicators/FimatheChannels"

# Cria o diretório de destino
mkdir -p "${INDICATOR_DEST}"

# Copia todos os arquivos e pastas da origem para o destino
cp -rv "${INDICATOR_SOURCE}/"* "${INDICATOR_DEST}/"

# --- Fim ---
echo "✅ Sincronização concluída! Arquivos prontos para compilação."
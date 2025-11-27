#!/bin/bash

# Configurações
ORIGEM="/www/mql/fimathe"
DESTINO="/www/mql/metatrader-folder/Experts/Fimathe"
PASTA_FIMATHE="$ORIGEM/MQL5/Experts/RoboFimathe"

# Verifica se origem existe
if [ ! -d "$ORIGEM" ]; then
    echo "Erro: Origem $ORIGEM não encontrada"
    exit 1
fi

# Remove destino antigo (limpa tudo)
rm -rf "$DESTINO"

# Cria estrutura se não existir
# mkdir -p "$DESTINO"

# Copia apenas a pasta Fimathe
if [ -d "$PASTA_FIMATHE" ]; then
    cp -r "$PASTA_FIMATHE" "$DESTINO"
    echo "✅ Atualizado: $DESTINO"
else
    echo "❌ Pasta $PASTA_FIMATHE não encontrada"
    exit 1
fi
#!/bin/bash

# Configurações
ORIGEM="/www/mql/fimathe"
DESTINO="/www/mql/fimathe/MQL5/Experts/Fimathe"
PASTA_FIMATHE="$ORIGEM/MQL5/Experts/Fimathe"

# Verifica se origem existe
if [ ! -d "$ORIGEM" ]; then
    echo "Erro: Origem $ORIGEM não encontrada"
    exit 1
fi

# Atualiza repositório origem
echo "Atualizando repositório em $ORIGEM..."
cd "$ORIGEM" && git pull origin main

# Remove destino antigo (limpa tudo)
rm -rf "$DESTINO"

# Cria estrutura se não existir
mkdir -p "$(dirname "$DESTINO")"

# Copia apenas a pasta Fimathe
if [ -d "$PASTA_FIMATHE" ]; then
    cp -r "$PASTA_FIMATHE" "$DESTINO"
    echo "✅ Atualizado: $DESTINO"
else
    echo "❌ Pasta $PASTA_FIMATHE não encontrada"
    exit 1
fi

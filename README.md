# Tailscale-ZLAN9809M Online Optimized

## English

### Overview

This repository provides an optimized way to run **Tailscale** on the **ZLAN9809M** industrial 4G router, based on **OpenWrt 21.02 / ramips / mipsel_24kc**.

The goal is to use the ZLAN9809M as a **Tailscale Subnet Router**, allowing remote access to devices connected to the router LAN, even when the 4G connection is behind **CGNAT**.

Because the ZLAN9809M has very limited persistent flash storage, this solution does not permanently install the Tailscale binary into the overlay filesystem. Instead:

- `tailscale.combined` is downloaded to `/tmp`;
- the binary is recreated at each boot;
- Tailscale identity/state is stored in `/etc/tailscale`;
- the OpenWrt service starts automatically at boot;
- once internet access is available, the loader downloads the binary and starts Tailscale.

---

### Recommended installation

Use the `install.sh` file from this repository.

The installer downloads the required files, creates or preserves the Tailscale configuration, installs the OpenWrt startup service, optionally installs the LuCI web interface, and can start the service immediately.

Required commands:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh
chmod +x /tmp/install-tailscale-zlan.sh
sh /tmp/install-tailscale-zlan.sh
```

During installation, you may be asked for:

- what to do if an existing installation is found;
- Tailscale device hostname;
- LAN subnet to advertise;
- optional Tailscale auth key;
- whether to install the LuCI web menu;
- whether to start the service immediately;
- whether to reboot after installation.

If an existing installation is detected, `install.sh` also offers an uninstall option.

---

### Manual installation

For manual installation, use these repository files as reference:

```text
tailscale.env
tailscale-loader.sh
tailscale-loader
tailscale.combined
```

File purpose:

| File | Purpose |
|---|---|
| `tailscale.env` | Main configuration file template |
| `tailscale-loader.sh` | Runtime loader script |
| `tailscale-loader` | OpenWrt init.d service |
| `tailscale.combined` | Combined Tailscale binary for the router |

Recommended target paths on the router:

| Repository file | Router path |
|---|---|
| `tailscale.env` | `/etc/tailscale/tailscale.env` |
| `tailscale-loader.sh` | `/usr/bin/tailscale-loader.sh` |
| `tailscale-loader` | `/etc/init.d/tailscale-loader` |
| `tailscale.combined` | `/tmp/tailscale.combined` |

The binary is intentionally placed in `/tmp` because the ZLAN9809M has very limited persistent overlay storage.

---

### LuCI web interface

This project includes an optional LuCI menu to manage the Tailscale loader from the OpenWrt web interface.

The LuCI menu can:

- show Tailscale status;
- show the Tailscale IP address;
- start, stop and restart the service;
- show loader logs;
- show running processes;
- show memory and disk usage;
- edit hostname;
- edit advertised routes;
- update or clear the auth key.

Required file:

```text
install-luci.sh
```

After installation, the menu should appear in LuCI under:

```text
Services → Tailscale ZLAN
```

The main installer can also install this menu automatically.

---

### Uninstall

The preferred uninstall method is to run `install.sh` again. If an existing installation is detected, choose the uninstall option from the installer menu.

The standalone uninstall script is also available:

```text
uninstall.sh
```

The uninstall process removes:

- OpenWrt init.d service;
- runtime loader script;
- temporary Tailscale binary;
- runtime symlinks;
- Tailscale runtime socket directory;
- temporary logs;
- LuCI menu files;
- LuCI cache.

During uninstall, you can choose what to do with the persistent Tailscale configuration:

```text
1) Keep /etc/tailscale files
2) Backup and remove /etc/tailscale files
3) Remove /etc/tailscale files without backup
4) Cancel uninstall
```

Keeping `/etc/tailscale` is useful if you plan to reinstall later and want to preserve the existing device identity in your tailnet.

Removing `/etc/tailscale` is useful if you want to completely remove this solution from the router.

---

### Repository files

| File | Description |
|---|---|
| `install.sh` | Main automatic installer and uninstall menu |
| `install-luci.sh` | Optional LuCI web menu installer |
| `uninstall.sh` | Standalone uninstall script |
| `tailscale.env` | Configuration template |
| `tailscale-loader.sh` | Runtime loader script |
| `tailscale-loader` | OpenWrt init.d service |
| `tailscale.combined` | Combined Tailscale binary |
| `luci/tailscale_zlan.lua` | LuCI controller |
| `luci/status.htm` | LuCI status/configuration page |
| `.gitattributes` | Ensures Linux-compatible LF line endings |

---

### Notes

Do not publish your Tailscale auth key in GitHub, documentation, screenshots, logs or issue reports.

If a script fails with errors such as `not found` or `unexpected end of file`, check that the repository files are using Linux-compatible LF line endings. The `.gitattributes` file is included to help prevent CRLF issues.

---

### Hardware specifications

The **ZLAN9809M** is an industrial 4G router with limited resources:

| Specification | Details |
|---|---|
| CPU | MediaTek MT7628A (580 MHz, mipsel_24kc) |
| RAM | 64 MB DDR2 |
| Flash Storage | 16 MB (limited overlay space) |
| Architecture | OpenWrt 21.02 / ramips / mipsel_24kc |
| Network | 4G LTE + Ethernet |
| Available Free Space | ~5 MB (after OpenWrt system) |

Due to these hardware constraints, this solution is designed to minimize disk and memory usage.

---

### Memory and storage usage

**Disk Storage (excluding tailscale.combined binary):**

- **Installation files** (temporary, downloaded from GitHub): ~18.6 KB
  - install.sh: 12.78 KB
  - install-luci.sh: 1.71 KB
  - uninstall.sh: 4.12 KB

- **Permanent installed files**: ~44 KB
  - /usr/bin/tailscale-loader.sh: 13.68 KB
  - /etc/init.d/tailscale-loader: ~5 KB
  - /usr/lib/lua/luci/controller/tailscale_zlan.lua: 5.1 KB
  - /usr/lib/lua/luci/view/tailscale_zlan/status.htm: 19.21 KB
  - /etc/tailscale/tailscale.env: 0.61 KB
  - /etc/tailscale/version.txt: 0.01 KB
  - /etc/tailscale/connection_history.txt: ~0.5 KB (max 10 entries)

- **Total permanent storage**: ~44 KB
- **Total with installation**: ~62 KB

**RAM Usage (excluding tailscale.combined binary):**

- tailscale-loader.sh (main script): ~1-2 MB
- tailscale-loader (watchdog service): ~0.5 MB
- monitor_vpn (background process): ~0.3 MB
- **Total RAM for scripts**: ~3-4 MB

**Temporary files in /tmp (volatile RAM):**

- /tmp/tailscale.combined: ~8-10 MB (binary, excluded from above)
- /tmp/tailscale-loader.log: ~50 KB (limited)
- /tmp/tailscale-runtime/: socket directory

**Impact on ZLAN9809M**: Minimal - scripts occupy less than 100 KB on disk and ~3-4 MB of RAM, well within the device constraints.

---

## Português

### Visão geral

Este repositório oferece uma forma otimizada de executar o **Tailscale** no roteador industrial **ZLAN9809M**, baseado em **OpenWrt 21.02 / ramips / mipsel_24kc**.

O objetivo é usar o ZLAN9809M como um **Tailscale Subnet Router**, permitindo acesso remoto aos dispositivos conectados à LAN do roteador, mesmo quando a conexão 4G está atrás de **CGNAT**.

Como o ZLAN9809M possui pouco espaço persistente disponível na flash, esta solução não instala permanentemente o binário do Tailscale no overlay. Em vez disso:

- `tailscale.combined` é baixado para `/tmp`;
- o binário é recriado a cada boot;
- a identidade/estado do Tailscale fica salva em `/etc/tailscale`;
- o serviço OpenWrt inicia automaticamente no boot;
- quando a internet está disponível, o loader baixa o binário e inicia o Tailscale.

---

### Instalação recomendada

Use o arquivo `install.sh` deste repositório.

O instalador baixa os arquivos necessários, cria ou preserva a configuração do Tailscale, instala o serviço de inicialização do OpenWrt, oferece a instalação da interface LuCI e pode iniciar o serviço imediatamente.

Comando necessário:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh
chmod +x /tmp/install-tailscale-zlan.sh
sh /tmp/install-tailscale-zlan.sh
```

Durante a instalação, você poderá escolher:

- o que fazer caso uma instalação existente seja encontrada;
- nome do dispositivo no Tailscale;
- sub-rede LAN a ser anunciada;
- chave de autenticação opcional do Tailscale;
- se deseja instalar o menu LuCI;
- se deseja iniciar o serviço imediatamente;
- se deseja reiniciar o roteador após a instalação.

Se uma instalação existente for detectada, o `install.sh` também oferece uma opção de desinstalação.

---

### Instalação manual

Para instalação manual, use os arquivos abaixo como referência:

```text
tailscale.env
tailscale-loader.sh
tailscale-loader
tailscale.combined
```

Função de cada arquivo:

| Arquivo | Função |
|---|---|
| `tailscale.env` | Modelo principal do arquivo de configuração |
| `tailscale-loader.sh` | Script de carregamento em tempo de execução |
| `tailscale-loader` | Serviço init.d do OpenWrt |
| `tailscale.combined` | Binário combinado do Tailscale para o roteador |

Caminhos recomendados no roteador:

| Arquivo do repositório | Caminho no roteador |
|---|---|
| `tailscale.env` | `/etc/tailscale/tailscale.env` |
| `tailscale-loader.sh` | `/usr/bin/tailscale-loader.sh` |
| `tailscale-loader` | `/etc/init.d/tailscale-loader` |
| `tailscale.combined` | `/tmp/tailscale.combined` |

O binário é colocado intencionalmente em `/tmp`, pois o ZLAN9809M possui pouco espaço persistente disponível no overlay.

---

### Interface web LuCI

Este projeto inclui um menu LuCI opcional para gerenciar o loader do Tailscale pela interface web do OpenWrt.

O menu LuCI permite:

- ver o status do Tailscale;
- ver o IP do Tailscale;
- iniciar, parar e reiniciar o serviço;
- ver os logs do loader;
- ver os processos em execução;
- ver uso de memória e disco;
- editar o hostname;
- editar as rotas anunciadas;
- atualizar ou limpar a auth key.

Arquivo necessário:

```text
install-luci.sh
```

Após a instalação, o menu deverá aparecer no LuCI em:

```text
Services → Tailscale ZLAN
```

O instalador principal também pode instalar esse menu automaticamente.

---

### Desinstalação

O método preferencial de desinstalação é executar o `install.sh` novamente. Se uma instalação existente for detectada, escolha a opção de desinstalação no menu do instalador.

O script separado de desinstalação também está disponível:

```text
uninstall.sh
```

O processo de desinstalação remove:

- serviço init.d do OpenWrt;
- script de carregamento em tempo de execução;
- binário temporário do Tailscale;
- symlinks temporários;
- diretório de runtime/socket do Tailscale;
- logs temporários;
- arquivos do menu LuCI;
- cache do LuCI.

Durante a desinstalação, é possível escolher o que fazer com a configuração persistente do Tailscale:

```text
1) Manter os arquivos em /etc/tailscale
2) Fazer backup e remover os arquivos em /etc/tailscale
3) Remover os arquivos em /etc/tailscale sem backup
4) Cancelar a desinstalação
```

Manter `/etc/tailscale` é útil caso você pretenda reinstalar depois e queira preservar a identidade atual do dispositivo na sua tailnet.

Remover `/etc/tailscale` é útil caso você queira apagar completamente esta solução do roteador.

---

### Arquivos do repositório

| Arquivo | Descrição |
|---|---|
| `install.sh` | Instalador automático principal e menu de desinstalação |
| `install-luci.sh` | Instalador opcional do menu LuCI |
| `uninstall.sh` | Script separado de desinstalação |
| `tailscale.env` | Modelo de configuração |
| `tailscale-loader.sh` | Script de carregamento em tempo de execução |
| `tailscale-loader` | Serviço init.d do OpenWrt |
| `tailscale.combined` | Binário combinado do Tailscale |
| `luci/tailscale_zlan.lua` | Controller LuCI |
| `luci/status.htm` | Página LuCI de status e configuração |
| `.gitattributes` | Garante finais de linha LF compatíveis com Linux |

---

### Especificações de hardware

O **ZLAN9809M** é um roteador industrial 4G com recursos limitados:

| Especificação | Detalhes |
|---|---|
| CPU | MediaTek MT7628A (580 MHz, mipsel_24kc) |
| RAM | 64 MB DDR2 |
| Armazenamento Flash | 16 MB (espaço de overlay limitado) |
| Arquitetura | OpenWrt 21.02 / ramips / mipsel_24kc |
| Rede | 4G LTE + Ethernet |
| Espaço Livre Disponível | ~5 MB (após sistema OpenWrt) |

Devido a essas restrições de hardware, esta solução foi projetada para minimizar o uso de disco e memória.

---

### Uso de memória e armazenamento

**Armazenamento em Disco (excluindo binário tailscale.combined):**

- **Arquivos de instalação** (temporários, baixados do GitHub): ~18.6 KB
  - install.sh: 12.78 KB
  - install-luci.sh: 1.71 KB
  - uninstall.sh: 4.12 KB

- **Arquivos instalados permanentemente**: ~44 KB
  - /usr/bin/tailscale-loader.sh: 13.68 KB
  - /etc/init.d/tailscale-loader: ~5 KB
  - /usr/lib/lua/luci/controller/tailscale_zlan.lua: 5.1 KB
  - /usr/lib/lua/luci/view/tailscale_zlan/status.htm: 19.21 KB
  - /etc/tailscale/tailscale.env: 0.61 KB
  - /etc/tailscale/version.txt: 0.01 KB
  - /etc/tailscale/connection_history.txt: ~0.5 KB (máximo 10 entradas)

- **Total armazenamento permanente**: ~44 KB
- **Total com instalação**: ~62 KB

**Uso de RAM (excluindo binário tailscale.combined):**

- tailscale-loader.sh (script principal): ~1-2 MB
- tailscale-loader (serviço watchdog): ~0.5 MB
- monitor_vpn (processo em background): ~0.3 MB
- **Total RAM para scripts**: ~3-4 MB

**Arquivos temporários em /tmp (RAM volátil):**

- /tmp/tailscale.combined: ~8-10 MB (binário, excluído acima)
- /tmp/tailscale-loader.log: ~50 KB (limitado)
- /tmp/tailscale-runtime/: diretório de socket

**Impacto no ZLAN9809M**: Mínimo - os scripts ocupam menos de 100 KB em disco e ~3-4 MB de RAM, bem dentro das restrições do dispositivo.

---

### Observações

Não publique sua Tailscale auth key no GitHub, documentação, capturas de tela, logs ou issues.

Se algum script falhar com erros como `not found` ou `unexpected end of file`, verifique se os arquivos do repositório estão usando finais de linha LF compatíveis com Linux. O arquivo `.gitattributes` está incluído para ajudar a evitar problemas com CRLF.

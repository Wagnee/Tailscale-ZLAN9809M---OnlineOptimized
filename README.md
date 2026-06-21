
# Português

## Tailscale para ZLAN9809M com carregamento otimizado em `/tmp`

Este repositório facilita o uso do **Tailscale** no roteador industrial **ZLAN9809M**, baseado em **OpenWrt 21.02 / ramips / mipsel_24kc**.

O objetivo é permitir que o ZLAN9809M funcione como um **Tailscale Subnet Router**, oferecendo acesso remoto aos dispositivos conectados à LAN do roteador, mesmo quando a conexão 4G está atrás de **CGNAT**.

Como o ZLAN9809M possui pouco espaço persistente disponível no overlay, esta solução não instala o binário completo do Tailscale permanentemente na flash. Em vez disso:

- o binário `tailscale.combined` é baixado automaticamente para `/tmp`;
- o binário é recriado a cada boot, sem ocupar espaço permanente;
- o estado/autenticação do Tailscale fica salvo em `/etc/tailscale`;
- o serviço inicia automaticamente com o OpenWrt;
- quando o roteador encontra internet, ele baixa o binário e inicia o Tailscale.

---

# English

## Tailscale for ZLAN9809M with optimized `/tmp` runtime loading

This repository makes it easier to run **Tailscale** on the **ZLAN9809M** industrial router, based on **OpenWrt 21.02 / ramips / mipsel_24kc**.

The goal is to allow the ZLAN9809M to work as a **Tailscale Subnet Router**, providing remote access to devices connected to the router LAN, even when the 4G connection is behind **CGNAT**.

Because the ZLAN9809M has very limited persistent overlay storage, this solution does not permanently install the full Tailscale binary into flash. Instead:

- the `tailscale.combined` binary is automatically downloaded to `/tmp`;
- the binary is recreated at each boot without permanently consuming flash storage;
- Tailscale state/authentication is stored in `/etc/tailscale`;
- the service starts automatically with OpenWrt;
- once the router has internet access, it downloads the binary and starts Tailscale.

---


## Installation / Instalação

### Automatic installation / Instalação automática

Use the `install.sh` file from this repository.

Run this in terminal:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh

chmod +x /tmp/install-tailscale-zlan.sh

sh /tmp/install-tailscale-zlan.sh
```

This is the recommended installation method. The installer downloads the required files, creates the Tailscale configuration, installs the OpenWrt startup service, and optionally installs the LuCI web interface.

During installation, you will be asked for:

* Tailscale device hostname
* LAN subnet to advertise
* Optional Tailscale auth key
* Whether to install the LuCI web menu
* Whether to start the service immediately

Required file:

```text
install.sh
```

Use o arquivo `install.sh` deste repositório.

Execute esses comandos em sequência no terminal:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh

chmod +x /tmp/install-tailscale-zlan.sh

sh /tmp/install-tailscale-zlan.sh
```

Este é o método de instalação recomendado. O instalador baixa os arquivos necessários, cria a configuração do Tailscale, instala o serviço de inicialização do OpenWrt e oferece a opção de instalar a interface web LuCI.

Durante a instalação, serão solicitadas as seguintes informações:

* Nome do dispositivo no Tailscale
* Sub-rede LAN a ser anunciada
* Chave de autenticação opcional do Tailscale
* Se deseja instalar o menu LuCI
* Se deseja iniciar o serviço imediatamente

Arquivo necessário:

```text
install.sh
```

---

### Manual installation / Instalação manual

For manual installation, use the files below as reference:

```text
tailscale.env
tailscale-loader.sh
tailscale-loader
tailscale.combined
```

File purpose:

| File                  | Purpose                                  |
| --------------------- | ---------------------------------------- |
| `tailscale.env`       | Main configuration file template         |
| `tailscale-loader.sh` | Runtime loader script                    |
| `tailscale-loader`    | OpenWrt init.d service                   |
| `tailscale.combined`  | Combined Tailscale binary for the router |

Recommended target paths on the router:

| Repository file       | Router path                    |
| --------------------- | ------------------------------ |
| `tailscale.env`       | `/etc/tailscale/tailscale.env` |
| `tailscale-loader.sh` | `/usr/bin/tailscale-loader.sh` |
| `tailscale-loader`    | `/etc/init.d/tailscale-loader` |
| `tailscale.combined`  | `/tmp/tailscale.combined`      |

The binary is intentionally placed in `/tmp` because the ZLAN9809M has very limited persistent flash storage.

Para instalação manual, use os arquivos abaixo como referência:

```text
tailscale.env
tailscale-loader.sh
tailscale-loader
tailscale.combined
```

Função de cada arquivo:

| Arquivo               | Função                                         |
| --------------------- | ---------------------------------------------- |
| `tailscale.env`       | Modelo principal do arquivo de configuração    |
| `tailscale-loader.sh` | Script de carregamento em tempo de execução    |
| `tailscale-loader`    | Serviço init.d do OpenWrt                      |
| `tailscale.combined`  | Binário combinado do Tailscale para o roteador |

Caminhos recomendados no roteador:

| Arquivo do repositório | Caminho no roteador            |
| ---------------------- | ------------------------------ |
| `tailscale.env`        | `/etc/tailscale/tailscale.env` |
| `tailscale-loader.sh`  | `/usr/bin/tailscale-loader.sh` |
| `tailscale-loader`     | `/etc/init.d/tailscale-loader` |
| `tailscale.combined`   | `/tmp/tailscale.combined`      |

O binário é colocado intencionalmente em `/tmp`, pois o ZLAN9809M possui pouco espaço de armazenamento persistente na flash.

---

## LuCI web interface / Interface web LuCI

This project includes an optional LuCI menu for managing the Tailscale loader directly from the OpenWrt web interface.

The LuCI menu allows you to:

* View Tailscale status
* View Tailscale IP
* Start, stop, and restart the service
* View loader logs
* Check running processes
* Edit hostname
* Edit advertised routes
* Update or clear the auth key

Required file:

```text
install-luci.sh
```

After installation, the menu should appear in LuCI under:

```text
Services → Tailscale ZLAN
```

The automatic installer can also install this menu at the end of the installation process.

Este projeto inclui um menu LuCI opcional para gerenciar o carregador do Tailscale diretamente pela interface web do OpenWrt.

O menu LuCI permite:

* Ver o status do Tailscale
* Ver o IP do Tailscale
* Iniciar, parar e reiniciar o serviço
* Ver os logs do loader
* Verificar os processos em execução
* Editar o hostname
* Editar as rotas anunciadas
* Atualizar ou limpar a auth key

Arquivo necessário:

```text
install-luci.sh
```

Após a instalação, o menu deverá aparecer no LuCI em:

```text
Services → Tailscale ZLAN
```

O instalador automático também pode instalar esse menu ao final do processo de instalação.

---

## Uninstall / Desinstalação

To remove this solution from the router, use the uninstall script.

Run this in terminal:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/uninstall.sh

chmod +x /tmp/install-tailscale-zlan.sh

sh /tmp/install-tailscale-zlan.sh
```

Required file:

```text
uninstall.sh
```

The uninstaller removes:

* OpenWrt init.d service
* Runtime loader script
* Temporary Tailscale binary
* Runtime symlinks
* Tailscale runtime socket directory
* Temporary logs
* LuCI menu files
* LuCI cache

During uninstall, you can choose what to do with the persistent Tailscale configuration:

```text
1) Keep /etc/tailscale files
2) Backup and remove /etc/tailscale files
3) Remove /etc/tailscale files without backup
4) Cancel uninstall
```

Keeping `/etc/tailscale` is useful if you plan to reinstall later and want to preserve the existing device identity in your tailnet.

Removing `/etc/tailscale` is useful if you want to completely remove this solution from the router.

Para remover esta solução do roteador, use o script de desinstalação.

Execute esses comandos em sequência no terminal:

```text
wget -O /tmp/install-tailscale-zlan.sh https://raw.githubusercontent.com/Wagnee/Tailscale-ZLAN9809M---OnlineOptimized/main/install.sh

chmod +x /tmp/install-tailscale-zlan.sh

sh /tmp/install-tailscale-zlan.sh
```

Arquivo necessário:

```text
uninstall.sh
```

O desinstalador remove:

* Serviço init.d do OpenWrt
* Script de carregamento em tempo de execução
* Binário temporário do Tailscale
* Symlinks temporários
* Diretório de runtime/socket do Tailscale
* Logs temporários
* Arquivos do menu LuCI
* Cache do LuCI

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

## Repository files / Arquivos do repositório

| File / Arquivo            | Description / Descrição                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| `install.sh`              | Main automatic installer / Instalador automático principal                                  |
| `install-luci.sh`         | Optional LuCI web menu installer / Instalador opcional do menu LuCI                         |
| `uninstall.sh`            | Complete uninstall script / Script completo de desinstalação                                |
| `tailscale.env`           | Configuration template / Modelo de configuração                                             |
| `tailscale-loader.sh`     | Runtime loader script / Script de carregamento em tempo de execução                         |
| `tailscale-loader`        | OpenWrt init.d service / Serviço init.d do OpenWrt                                          |
| `tailscale.combined`      | Combined Tailscale binary / Binário combinado do Tailscale                                  |
| `luci/tailscale_zlan.lua` | LuCI controller / Controller LuCI                                                           |
| `luci/status.htm`         | LuCI status/configuration page / Página LuCI de status e configuração                       |
| `.gitattributes`          | Ensures Linux-compatible LF line endings / Garante finais de linha LF compatíveis com Linux |

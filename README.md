
Olá! Sou Frederico Cabral Uchôa e este é o meu projeto de estágio! Ele consiste em um aplicativo para avaliação do serviço prestado pelo restaurante interno da empresa Costa Foods Brasil. 

# Aplicativo *Costa Foods Brasil Feedbacks*

A aplicação é desenvolvida através do kit de desenvolvimento de software _**Flutter**_. O objetivo é coletar avaliações de colaboradores sobre o Restaurante ou a Ambientação da Empresa usando totens/tablets em modo Kiosk.

<div>
<img src="https://github.com/user-attachments/assets/ec11c468-93de-4d40-994d-09fb0538918e" width="23%" />
<img src="https://github.com/user-attachments/assets/47066966-c4f1-4ab9-82b2-7e931813b76b" width="23%" />
<img src="https://github.com/user-attachments/assets/120e0f0b-ff44-433a-853a-f13c254fb13c" width="23%" />
<img src="https://github.com/user-attachments/assets/672cbdb9-2e85-4956-873e-f5004d634b6a" width="23%" />
</div>

---

## 1. Visão Geral e Regras de Negócio

A aplicação possui dois modos principais de operação:
* **Modo 1 (Restaurante):** Focado em avaliar *Refeição*, *Serviço* e *Ambiente*. Trabalha de forma inteligente com 5 turnos dinâmicos baseados no relógio do tablet (Café da Manhã, Almoço, Café da Tarde, Jantar e Ceia).
* **Modo 2 (Ambientação da Empresa):** Focado em avaliar *Acolhimento*, *Organização* e *Conteúdo*. O turno é classificado de forma fixa como "Ambientação".

**Regra das Avaliações:**
* **Avaliações Positivas (4 e 5) ou Neutras (3):** Podem ser enviadas diretamente.
* **Avaliações Negativas (1 e 2):** Exigem, obrigatoriamente, que o usuário selecione um botão de motivo (detalhe do problema) ou digite um comentário antes de habilitar o botão de envio.

---

## 2. Arquitetura Técnica e Tecnologias

* **Linguagem / Framework:** Dart & Flutter.
* **Gerenciamento de Estado:** `Provider` (A classe principal `AppData` controla todas as lógicas de negócio e estado em tempo real).
* **Armazenamento Seguro (Offline-first):**
  * **Cofre Interno:** O app usa `SharedPreferences` para manter cópias invisíveis dos dados e evitar perda de histórico caso o aparelho fique offline ou o arquivo físico seja apagado.
  * **Backup Físico:** Arquivos `.csv` salvos diretamente na pasta *Downloads* do Android via sistema customizado (`file_helper.dart`).
* **Kiosk Mode e Segurança:**
  * Utiliza o pacote `wakelock_plus` para impedir que o tablet desligue a tela.
  * Integração nativa via `MethodChannel('com.costafoods.app/kiosk')` para acionar o *Modo Imersivo*, bloqueando botões de navegação do Android (Home, Voltar e Recentes).
* **Integração com Servidor Local:** Realiza requisições HTTP (`POST`) em rede local enviando o backup em formato *JSON* e *Multipart File* (CSV) para o servidor, em Python, do *Costa Foods Planning* (`http://10.1.32.181:5000/`).

---

## 3. Dicionário de Dados e Estrutura do CSV

Para garantir que o servidor Python ou Excel não sofra erros de leitura, a nomenclatura do arquivo gerado e exportado dinamicamente possui formatação limpa (ex: `avaliacoes_restaurante_matriz_administrativo.csv`). 

A estrutura fixa de colunas do relatório gerado é a seguinte:

| # | Coluna | Descrição |
|---|---|---|
| 1 | **Unidade** | Unidade avaliada com a variação do uniforme se houver (Ex: *Matriz - Branco*). |
| 2 | **Data/Hora** | Timestamp no formato ISO 8601. |
| 3 | **Turno** | Refeição detectada (Ex: *Almoço*, *Café da Manhã* ou *Ambientação*). |
| 4 | **Avaliação** | Valor numérico (1 a 5 estrelas). |
| 5 | **Categoria** | Texto da avaliação (*Excelente, Bom, Neutro, Ruim, Péssimo*). |
| 6 | **Status de Satisfação** | Consolidação em *Satisfeito*, *Neutro* ou *Insatisfeito*. |
| 7 | **refeição_positivo** | Detalhe positivo (Muda para *acolhimento_positivo* no Modo 2). |
| 8 | **refeição_negativo** | Detalhe negativo (Muda para *acolhimento_negativo* no Modo 2). |
| 9 | **serviço_positivo** | Detalhe positivo (Muda para *organizacao_positivo* no Modo 2). |
| 10| **serviço_negativo** | Detalhe negativo (Muda para *organizacao_negativo* no Modo 2). |
| 11| **ambiente_positivo** | Detalhe positivo (Muda para *conteudo_positivo* no Modo 2). |
| 12| **ambiente_negativo** | Detalhe negativo (Muda para *conteudo_negativo* no Modo 2). |
| 13| **Comentário** | Texto livre digitado pelo usuário (opcional na maioria dos casos). |

---

## 4. Acesso ao Aplicativo

Ele atualmente se encontra na Google Play Store, porém está no período de Teste Interno. Dessa forma, só pode ser baixado naqueles dispositivos que contenham algum e-mail do Gmail cadastrado previamente por mim no Google Play Console. 

Portanto, caso o e-mail vinculado ao seu dispositivo ainda não tenha permissão para baixá-lo, envie-o para mim, para meu e-mail: frederico.uchoa@avivar.com.br (ou fcabral254@gmail.com), que o cadastro na plataforma. 

Com o seu acesso liberado, entre no link para baixá-lo na na Google Play (devido ele ainda não está disponível para a visualização pública na loja por estar no período de testes): https://play.google.com/apps/internaltest/4700239093349532737.

---

## 5. Retrocompatibilidade (Aviso de Dados Legados)

A interface de avaliações sofreu atualizações de nomenclatura. Para garantir que o histórico antigo não desapareça das estatísticas e da geração de CSV, o dicionário interno do aplicativo faz mapeamentos duplos.

**Mapeamentos Antigos Mantidos no Parse:**
* O gerador de relatórios entende tanto o texto novo `"Refeição quente"` quanto o antigo `"Comida Quente"`.
* O gerador de relatórios entende tanto o texto novo `"Refeição fria"` quanto o antigo `"Comida Fria"`.

*Por favor, não remova os termos antigos da classe `AppData` (método `getRestaurantPhrases`), sob o risco de corromper a leitura do banco de dados antigo contido nos tablets.*

---

## Como rodá-lo para futuras modificações
- Baixe no computador os programas Visual Studio Code e Android Studio;
- Crie um ambiente de emulação de um dispositivo mobile através de Device Manager > Add a new device > Create Virtual Device > Tablet (caso deseja emular um tablet) > Medium **ou** Pixel Tablet > Next > Finish;
- Abra o diretório deste projeto no VS Code;
- Baixe e instale o Flutter SDK (Software Development Kit) mais recente do site oficial do Flutter;
- Adicione o caminho para o diretório bin do Flutter à variável de ambiente PATH do sistema operacional. Isso permite que os comandos flutter e dart sejam executados de qualquer local;
- Abra o VS Code, vá para a seção de Extensões (Ctrl+Shift+X) e instale as extensões oficiais "Flutter" e "Dart";
- Abra o terminal (no VS Code ou no sistema) e execute: ```flutter doctor```;
- Aceite as Licenças do Android (se o flutter doctor indicar que faltam as licenças, execute: ```flutter doctor --android-licenses```. Aceite os termos digitando 'y' quando solicitado;
- No VS Code, abra a pasta raiz do projeto que foi baixado;
- Abra o terminal do VS Code (Ctrl+Shift+') e execute o comando para instalar todos os pacotes listados no arquivo ```pubspec.yaml
```: ```flutter pub get```;
- Com o emulador rodando e selecionado na barra de status do VS Code, pressione F5 (ou vá em Run > Start Debugging) para compilar e rodar o aplicativo no dispositivo virtual.

### Código principal
```lib/main.dart```

### Dependências
```pubspec.yaml```

---

# Informações úteis

## Acessar CSV (Backup Automático)
O aplicativo agora salva backups diretamente na pasta pública do dispositivo.
### Pelo PC (Device Explorer)
No Android Studio, vá em ```View/Tools/Device Explorer``` e navegue até 
```/storage/emulated/0/Download/```. Você encontrará os arquivos ```feedbacks_costafoods_1.csv``` (Restaurante) ou ```feedbacks_costafoods_2.csv``` (Ambientação).
### Por dispositivo mobile
Basta abrir o aplicativo "Meus Arquivos" ou "Gerenciador de Arquivos" do Android e ir na pasta **Downloads**.

## Passos ao adicionar ícone novo
- Adicione uma imagem com o nome ```costa_foods_feedbacks.png``` nas pastas ```assets/icon``` e  ```assets/images``` (caso queira a mesma imagem de fundo e de ícone do aplicativo);
- Feche o aplicativo se estiver rodando no emulador;
- Copie o grupo de comandos abaixo para o terminal dentro do diretório do projeto (ex: no terminal do próprio VS Code) e insira **A** (ou **a**) quando aparecer uma pergunta.
```bash
Remove-Item  android/app/src/main/res/mipmap-*
Remove-Item -Recurse -Force android/app/src/main/res/drawable-*
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
```
## Gerar APK do aplicativo
Copie o seguinte grupo de comandos para o terminal dentro do diretório do projeto (ex no terminal do próprio VS Code):
```
flutter clean
flutter pub get
flutter build apk --release --no-tree-shake-icons
```
Feito isso, ele encontra-se dentro do diretório do projeto em ```\build\app\outputs\flutter-apk```.

No Windows, por exemplo, ele se encontra em ```C:\Users\Seu_Usuário\Aplicativo-Avaliacao-Restaurante-CostaFoods\build\app\outputs\flutter-apk```.

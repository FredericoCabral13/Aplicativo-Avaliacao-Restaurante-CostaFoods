# Aplicativo *Costa Feedbacks*
Olá! Sou Frederico Cabral Uchôa e este é o meu projeto de estágio! Ele consiste em um aplicativo para avaliação do serviço prestado pelo restaurante interno da empresa Costa Foods Brasil. 

A aplicação é desenvolvida através do kit de desenvolvimento de software _**Flutter**_.

<img width="251.23621" height="400" alt="image" src="https://github.com/user-attachments/assets/63db5bd2-9ef2-4652-8d3f-74cd8944de87" />
<img width="250.803826" height="400" alt="image" src="https://github.com/user-attachments/assets/8069480a-325e-4e8f-9f5f-ad6abf3b73b3" />
<img width="250.752728" height="400" alt="image" src="https://github.com/user-attachments/assets/6d209da6-e8a5-4e49-abd3-c5bca260d70f" />

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
- Abra o terminal do VS Code (Ctrl+Shift+') e execute o comando para instalar todos os pacotes listados no arquivo ```pubspec.yaml```: ```flutter pub get```;
- Com o emulador rodando e selecionado na barra de status do VS Code, pressione F5 (ou vá em Run > Start Debugging) para compilar e rodar o aplicativo no dispositivo virtual.
## Código principal
```lib/main.dart```

## Dependências
```pubspec.yaml```

# Informações úteis
## Acessar CSV 
### Pelo PC 
No Android Studio, vá em ```View/Tools/Device Explorer``` e depois em ```data/data/com.example.app_restaurante/app_flutter/avaliacoes_registros.csv```.
### Por dispositivo mobile
Vá até o diretório ```data/data/com.example.app_restaurante/app_flutter/avaliacoes_registros.csv```.

## Passos ao adicionar ícone novo
- Feche o aplicativo se estiver rodando no emulador;
- Copie o grupo de comandos abaixo para o terminal dentro do diretório do projeto (ex: no terminal do próprio VS Code);
- Insira **A** (ou **a**) quando aparecer uma pergunta.
```
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

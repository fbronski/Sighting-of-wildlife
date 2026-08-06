# Sighting-of-wildlife
Local wildlife monitoring system for reliable detection and analysis of animal activity. All data is processed and stored on-site—without relying on third-party cloud providers. This ensures full data control, high reliability, and privacy-friendly operation.
**Schematic representation**
<img width="1536" height="1024" alt="ChatGPT Image 6  Aug  2026, 11_43_31" src="https://github.com/user-attachments/assets/e1284f69-e00b-44df-a57e-ccc70eb1acb9" />
  
## What components does the project consist of?
1. Hardware:
    - You’ll need a small server or a VM from a cloud provider of your choice; personally, I run mine on a mini server in the basement of my house             I’m      using a Lenovo ThinkCentre M920q MP there.
    - You’ll also need good 4G wildlife cameras that can upload data quickly and don’t glow when the flash goes off, but have enough LEDs to take good photos at night, as well as camera system software that supports **FTP or FTPS/S**. My recommendation here would be the T5.8 Cellular Trail Camera, pictured here, manufactured by willfine.com.
   - I would also recommend connecting the camera to an old 12-volt car battery housed in a waterproof plastic box designed for boatbuilding, so that you don’t have to change the AA batteries every week; a small 50–60 Ah car battery lasts me at least six months without needing recharging.
   - and last but not least, a pay-as-you-go SIM card with a monthly data allowance of 3–5 GB per trail camera
- <img width="312" height="360" alt="Bildschirmfoto 2026-08-04 um 21 05 26" src="https://github.com/user-attachments/assets/b3492ef7-c37d-4a3c-9ee4-ddf70087a543" />
2. Software:
  - First of all, you’ll need an operating system that supports Docker for containerisation – this could be Linux, macOS or Linux. The important thing is that this OS supports .NET 10 builds. Personally, I use Linux, specifically the Ubuntu Server LTS 26.04 distribution, without any unnecessary bells and whistles that would just waste resources. Depending on how many trail cameras you’re using – in my case, four – I’d recommend 2–4 CPUs, 4–8 GB of RAM and 150–300 GB of hard disk space on Ubuntu.
  - Secondly, I’m using the Immich app (Community Edition) to install it on your home server. You can find the Immich project here. https://github.com/immich-app/immich, Please also support the Immich team in their work on the incredible Immich app – developing something like this and offering it to the community for free is simply brilliant.
  - Thirdly, you’ll need my piece of software called <ins>**JagdBildBot**</ins>, which processes the photos received from the trail cameras, automatically recognises them using YOLO, tags and plots them where necessary, notifies you via push notification on the iOS app when new sightings are detected, uploads the received image to the Immich app via the Immich API, and adds it to an album created on Immich.
  - Fourthly, you’ll need the iOS app ‘Wildsichtungen’ to receive the images, push notifications and manage the results. Both the iOS app and the JagdBildBot service are included in this repository. At the moment, I haven’t released the Wildsichtungen app on the Apple App Store, which means that to get it onto your Apple iPhone, you’ll need to deploy it there via Xcode using your Apple Developer Account. If I receive any requests, I’ll certainly add it to the Store without the usual advertising clutter if i get more than once requests.
  - And finally, you’ll need some OS tools: Docker, VFTP and UFW. In the installation guide, I’ll explain how to install and set these up on Linux Ubuntu 26.04. You’ll also need your own subdomain, such as sichtung.domain.de, as well as the ability to receive data over the internet via FTP or FTP/S, which usually requires your own IP address.
  - **If this isn’t a problem for you, please proceed to the next step of the installation and roll-out of the software**

3. Installation:
  - Install Linux
    - There are indeed many ways to install a fully functional Linux system; if you do not wish to do this, I recommend setting up a virtual machine (VM) with a cloud provider of your choice. Please check the privacy policy, as well as the data protection regulations of the country in which the data centre is located. Within the EU, I recommend the data centre operated by UniCom Service GmbH in Cologne; UniCom will also be happy to assist you with sourcing trail cameras and so on.
  - Install VFTP Docker .Net 10 on your OS (here Linux ubuntu 26.04)
      - Update your Ubunutu with "sudo apt update" and "sudo apt upgrade -y"
      - VFTP with "sudo apt install vsftp"
        - On the VFTP konfiguration is it is very important to Use passiv mode, and you running FTP or FTP/S both not both zhere are an security issue
          <img width="625" height="693" alt="Bildschirmfoto 2026-08-06 um 13 05 08" src="https://github.com/user-attachments/assets/4ca5157c-bd78-44e8-8a8f-c53a19665145" />

      - .Net 10 SDK and Runtime with "sudo snap install dotnet-sdk"
      - Docker with "sudo apt install docker.io util-linux-extra"
      - **Important: _Please switch your Firewall here UFW to ON and open only your FTP or FTP/S and HTTPS ports_**
  - Install Immich Photo App
      - Install Immich on Docker see [Immich Docker Installation Guide](https://docs.immich.app/install/docker-compose)
        Once Immich has been successfully deployed on Docker and the necessary domain, firewall and certificate installations have been completed, Immich might look like this.
        <img width="5712" height="4284" alt="IMG_2073" src="https://github.com/user-attachments/assets/9c8047de-3327-4cf1-b5ee-5b34bb563acd" />

  - Install & Configure Kameras
      - Please select your camera settings, in particular the image quality, the interval between images, and the sensitivity of the motion detector sensor. Configure the FTP service settings, specifying the transfer protocol (FTP or FTPS), the IP address of your Linux system (please do not use domain names), the username and password, and the IP port to be used (e.g. 21 for FTP). 
4. IOS App
  - ...build Cooming soon
  - ...configure IOS APP
5. Build Linux .Net 10 Bot called JagdBildBot
  - ...build Comming soon
  - ...configure JagdBildBot

6. Joy and Fun with your Sighting of Wildlife
   


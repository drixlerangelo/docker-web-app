# Docker Web Application Setup Template
---
## Requirements
For this to work, you need to have administrative privileges. Also, you're going to need these programs in your system:
- Apache
- Docker

## How to use
1. Clone this repo using the following format:
    ```
    git clone https://github.com/drixlerangelo/docker-web-app.git <your.domain.here>

    example:
    git clone https://github.com/drixlerangelo/docker-web-app.git www.example.com
    ```
2. Make the `webbuilder.sh` script executable, e.g.
    ```
    chmod +x ./webbuilder.sh
    ```
The script has three (3) required and two (2) optional parameters.
  - Required parameters:
    - HTTP_PORT (-u)
      - It is only available in localhost
      - You can choose up to 65536, as long the port is open
      - It is where Apache will direct to when calling your domain via HTTP
    - HTTPS_PORT (-s)
      - It is only available in localhost
      - You can choose up to 65536, as long the port is open
      - It is where SSL is enabled
      - It is where Apache will direct to when calling your domain via HTTPS
    - EMAIL (-e)
      - It is used by Let's Encrypt for their registration
  - Optional parameters:
    - DOMAIN (-d)
      - If you didn't change this repo's name, or you want to change the name of your domain, you can change it here
      - The default is this repo's directory name
    - PHP_IMG (-p)
      - It is a tag of the PHP Docker image
      - The default is `apache`
      - You can find different tags [here](https://hub.docker.com/_/php?tab=tags&page=1&name=apache)
3. Run the script with the parameters you provide. E.g.
    ```
    ./webbuilder.sh -u 8080 -s 4433 -e webmaster@example.com -p 8.1.0-apache
    ```

4. Place your website (the ones with `index.php` or `index.html`) in the `www` folder.

Now you're done. Congrats on your newly-created website! 🥳

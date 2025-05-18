# Kuro
Fetch GitHub User Info by username

```
  _  __                       
 | |/ /  _   _   _ __    ___  
 | ' /  | | | | | '__|  / _ \ 
 | . \  | |_| | | |    | (_) |
 |_|\_\  \__,_| |_|     \___/ 

```

## Install

To use the Kuro script, follow these steps:

1. Clone the repository:

    ```
    git clone https://github.com/haithamaouati/Kuro.git
    ```

2. Change to the Kuro directory:

    ```
    cd Kuro
    ```
    
3. Change the file modes
    ```
    chmod +x kuro.sh
    ```
    
5. Run the script:

    ```
    ./kuro.sh
    ```

## Usage
Usage: `./kuro.sh -u <USERNAME> [-r]`

##### Options:

`-u`, `--username`   Specify the GitHub username to fetch info (required)

`-r`, `--repo`       Fetch all repositories

`-h`, `--help`    Show this help message

## Dependencies

The script requires the following dependencies:

- [figlet](http://www.figlet.org/): `pkg install figlet - y`
- [curl](https://curl.se/): `pkg install curl - y`
- [jq](https://jqlang.org/): `pkg install jq -y`

Make sure to install these dependencies before running the script.

## Author

Made with :coffee: by **Haitham Aouati**
  - GitHub: [github.com/haithamaouati](https://github.com/haithamaouati)

## License

Kuro is licensed under [WTFPL license](LICENSE)

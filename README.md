# guideMan
```text
         ^ 
       *****
     *********          
       *- -*
      * o o *
       * - *
   /||||   ||||\
       ** **
       ** **
       \/ \/
```

 A simple script to split the traffic of a certain app or script and direct it to your desired interface or tunnel.
## Installation
* First get the root user
```sh
sudo su
```
* Run install.sh script to install prerequisites.
```sh
./install.sh
```

## Run guideMan.sh
* First get the root user
```sh
sudo su
```

To use guideMan.sh with a script use the following template:
```sh
 ./guideMan.sh --interface 'interfaceName' --script '/route/to/script'
 Example: ./guideMan.sh --interface eth0 --script './test.sh'

 ```

* Note that Instead of giving a script address to --script param, you can also type one line commands.
For instance command below will start a firefox process and direct its traffic to eth0.
```sh
./guideMan.sh --interface eth0 --script firefox
```

## How to terminate 
Use one of the following ways:
1. press `CTRL+c`
2. issue `kill -15 proessID`

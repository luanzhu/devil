Devil
=====

Devil is a small tool to make it easier to update programs managed by [Angel](https://github.com/MichaelXavier/Angel) (the excellent process monitor tool).  Angel starts processes.  Devil kills running processes when an update is detected.

Why?
=====

I really like Angel.  It is the best process monitor/management tool I have ever used.  I have been using it to manage several small yesod applications and cannot be happier with its stability and performance.  Angel can do a lot of things for you automagically.  However, one thing it does not do is to restart your program after you upload a new version.

Devil is designed to handle program updates.  It will monitor an upcoming folder.  Whenever a new version is uploaded, it will update program and kill its all running processes.  Angel will restart the program, thus to complete the update cycle.

Another big motivation is to learn haskell and have some fun.  Even though I am new to haskell, I find it is a very fun language to play with.

Supported System
=====

Devil depends on inotify to monitor incoming folder.  As a result, it cannot be compiled on a system without inotify.  It was tested on Debian 7 with GHC 7.4.1, and 7.8.2.

Build
=====

The build environments I tried included GHC 7.4.1 with cabal 1.18.1.2, and GHC 7.8.2 with cabal 1.20.0.1. Run these command in the project's folder.

```Shell
cabal-dev install-deps
cabal-dev configure
cabal-dev build
```
Cabal 1.18 or later has the sandbox feature built-in. I had problems with cabal-dev and could not get the ghci working. Switching to cabal sandbox fixed the problem.
```Shell
cabal sandbox init
cabal install --only-dependencies
cabal configure
cabal build
```

The resulted binary file is

```Shell
dist/build/devil/devil
```

Alternatively, if you just like to build the binary with cabal sandbox, you can try:
```Shell
mkdir devil-bin
cd devil-bin
cabal sandbox init
cabal install devil
#binary file will be installed into ".cabal-sandbox/bin"
```

Configuration
=====

Configuration file is in JSON format.  Here is an example with explanations. 

__Please note: JSON does not support actual comments.  The comments in the following example are for explanation purpose only.  The actual configuration file should not contain any comments.__

```JSON
{
    /***************************************************************************
     * Devil will monitor incomingFolder for file updates.  Whenever you need
     * to update a program, you just need to upload the updated binary into 
     * this folder.  Devil and Angel will take care of the restart process.
     ***************************************************************************/
    "incomingFolder": "/home/zhu/tmp",
    "watchItems":
    [
        {
            /*******************************************************************
             * Each watch item should match a program managed by Angel.
             * 
             * binaryFileName is the file name devil watches in the 
             * incoming folder.  The file name should be eaxactly the same as 
             * the binary file managed by Angel.
             * 
             * Once a new or updated file is detected, devil will:
             *      (1). update the program in the target folder;
             *      (2). kill the running processes.
             *
             * PID file name follows the same name convention of Angel.  In this
             * example, devil will try to read PID from rate.pid and 
             * rate-?.pid (? denotes numbers).
             *******************************************************************/
            "binaryFileName": "rate",
            "targetFolder": "/home/zhu/rate",
            "pidFile": "/home/zhu/rate-web/rate.pid"
        },
        //You can have as many watch items as you like
        {
            "binaryFileName": "app2",
            "targetFolder": "/home/zhu/app2",
            "pidFile": "/home/zhu/app2/app2.pid"
        },
    ]
}
```

Run the program
=====

This program is designed to work with screen.  To start it in a named but detached screen session:
```Shell
screen -S devil -d -m ./devil configure.json
```

To reconnect it with screen:
```Shell
screen -S devil -r
```

To detach from screen when you are inside a screen session:
```Shell
ctrl+a d
```
Sample output of devil:
```Shell
zhu@debian:~/devil$ ./dist/build/devil/devil configure.json
Trying to load configuration from configure.json
Configuration {incomingFolder = "/home/zhu/tmp", watchItems = [Item {binaryFileName = "rate", targetFolder = "/home/zhu/rate-web", pidFile = "/home/zhu/rate-web/rate.pid"}]}
Watching incoming folder [/home/zhu/tmp]. Hit enter to terminate.
****************File Change Detected****************
Changes to [rate] was detected.
Copied from [/home/zhu/tmp/rate] to [/home/zhu/rate-web/rate].
Restore file mode for [/home/zhu/rate-web/rate].
Process IDs to be killed: ["11182"]
Killed!
```

Contributing
=====

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request




Devil
=====

Devil is a small tool to make it easier to update programs managed by [Angel](https://github.com/MichaelXavier/Angel) (the excellent process monitor tool).  Angel starts processes.  Devil kills running processes when an update is detected.

Why?
=====

I really like Angel.  It is the best process monitor/management tool I have ever used.  I have been using it to manage several small yesod applications and cannot be happier with its stability and performance.  Angel can do a lot of things for you automagically.  However, one thing it does not do is to restart your program after you upload a new version.

Devil is designed to handle program updates.  It will monitor an upcoming folder.  Whenever is new version is uploaded, it will update program and kill all running processes.  Angel will restart the program, thus to complete the update cycle.

Another big motivation is to learn haskell as I am new to haskell and would like to do more projects in future.

Supported System
=====

Devil depends on inotify to monitor incoming folder.  As a result, it will not be compiled on a system without inotify.  It was tested on Debian 7 with GHC 7.4.1.

Build
=====

The only build environment I tried is GHC 7.4.1, cabal 1.14.0, cabal-dev 0.9.2. 

```Shell
cabal-dev install-deps
cabal-dev configure
cabal-dev build
```

The resulted binary file is

```Shell
dist/build/devil/devil
```



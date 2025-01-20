## mineCORE 4 (Alpha)

> [!WARNING]
> This system is designed to demonstrate the capabilities of the next generation of mineCORE. Keep in mind that everything that is here is changing and improving, and may end up in a completely different form.

### Welcome to mineCORE 4 Alpha!

Here is the Alpha version of the next generation of the mineCORE project, which has been rewritten in order to immerse you more in a POSIX-compatible environment and introduce you to it in OpenComputers. The project was created by the mineSYS team and is being developed by it.
After completing the basic work and testing on the project, it will be located in the main mineCORE repository.

### Image deployment and installation

To deploy an image and start using this project, download the version of the image in the project releases, and unzip it to any empty disk using [MineOS](https://github.com/IgorTimofeev/MineOS). You need to unpack it in the root of an empty disk, so that when you select it, you can boot into the mineCORE 4 environment.

> [!NOTE]
> Look at the disk carefully: files must be unpacked strictly at the root of an empty disk, otherwise you will not be able to boot into the system.

### How do I log in?

Use the following data for authorization

```
Login: root
Password: root
```

### TODO: project development map

- [x] Full implementation of POSIX environment
- [x] Implementation of UNIX-like system and kernel environment
- [ ] Implementation of the initial version of the package manager and repository update system
- [x] Implementing Groups and User Rights in UserMgr
- [x] Executing commands and scripts as superuser (sudo)
- [ ] Implementation of MTAR and PKG support in the system

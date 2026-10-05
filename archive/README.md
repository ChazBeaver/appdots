# archive/

Reserved for removal scripts for packages/apps you used to run. There are
currently no removal scripts in this directory; the tree below illustrates
the naming convention, not existing commands. For current installation and
maintenance commands, see [MANUAL.md](../MANUAL.md).

## When to add here

You've decided to stop using something (RetroArch, a paid app, a theme set).
Write a clean removal script, run it, then commit the script here. Next time
you look at this directory you'll see:

- what you used to have
- how you cleanly removed it
- approximately when (from git history)

## Layout

Mirror the `packages/` and `system/` convention:

```
archive/
├── linux/
│   └── retroarch.sh
└── macos/
    └── (future removals)
```

## Not run by bootstrap.sh

`bootstrap.sh` never touches `archive/`. These are one-shot scripts you invoke
manually when you decide to remove something.

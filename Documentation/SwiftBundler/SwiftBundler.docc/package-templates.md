# Package templates

Easily create common types of apps from templates.

## Overview

Package templates reduce the amount of boiler plate code you have to replicate when creating a new project.

## Default templates

Swift Bundler comes with a few useful templates by default. Use the following command to list them:

```sh
swift bundler templates list
```

The default templates are located at `~/Library/Application Support/dev.stackotter.swift-bundler/templates` and are downloaded from [the swift-bundler-templates repository](https://github.com/stackotter/swift-bundler-templates) when the first command requiring templates is run.

Use the following command to get more information about each template:

```sh
swift bundler templates info [template]
```

Once you have decided which template you want to use, you can create a package from the template:

```sh
swift bundler create [app-name] --template [template]
```

## Troubleshooting

If you run into issues relating to templates, you may want to try updating the default templates:

```sh
swift bundler templates update
```

## Topics

### Custom templates

- <doc:custom-templates>

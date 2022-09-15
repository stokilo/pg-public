### Postgraphile + AWS lambda + SST

Proof of concept of deploying Postgraphile on AWS Lambda.

[https://www.graphile.org/postgraphile/](https://www.graphile.org/postgraphile/)

Official documentation for AWS lambda deployment:

[https://github.com/graphile/postgraphile-lambda-example](https://github.com/graphile/postgraphile-lambda-example)

This repository has some additional integrations i.e. data migration from npm scripts/typescript typings generation/
schema generation and caching/SST integration/React app integration. 

### Build

Install dependencies
```shell
yarn
```

Run SST in dev mode (remove sso script from package.json in case you don't use SSO)
```shell
yarn start
```

Run react client
```shell
yarn run dev
```
Replace Rest API URL in main.tsx

### Data migration

Run
```shell
yarn migrate
```

It will create database schema and populate with initial data.

### Notes
This is sandbox app. Some stacks are unsafe i.e. RDS endpoint is placed in public subnet!!!. Some settings are hardcoded i.e. API
URL in the file main.tsx.

Change also S3 bucket names in the S3Migration.ts - these originally are assigned to author's package name.

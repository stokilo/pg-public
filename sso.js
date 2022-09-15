const shell = require('shelljs')

const exec2JSON = (command) => {
  const raw = shell.exec(command, { silent: true })
  return raw.code === 0 ? JSON.parse(raw) : {}
}

const exec2Text = (command) => {
  const raw = shell.exec(command, { silent: true })
  return raw.code === 0 ? raw.stdout.replace(/[\r\n]/gm, '') : ''
}

const ssoLogin = (awsProfileName) => {
  shell.echo('SSO login')
  try {
    shell.exec(`aws sso login --profile ${awsProfileName}`)
  } catch (e) {
    console.dir(e)
    return false
  }
  return true
}

const ssoRefresh = () => {
  const awsProfileName = 'default'

  shell.echo(`ASW profile name for SSO: ${awsProfileName}`)

  const awsRegionCmd = exec2Text(`aws --profile ${awsProfileName} configure get sso_region`)
  const awsRegion = !awsRegionCmd.length ? 'us-east-1' : awsRegionCmd

  shell.echo(`AWS SSO region: ${awsRegion}`)

  const callerIdentity = exec2JSON(`aws --profile ${awsProfileName} sts get-caller-identity`)
  if (!('Account' in callerIdentity)) {
    ssoLogin(awsProfileName)
    ssoRefresh()
    return
  }

  const sessionName = callerIdentity.Arn.split('/')[1]
  const roleArn = `arn:aws:iam::${callerIdentity.Account}:role/aws-reserved/sso.amazonaws.com/${sessionName}`
  const credentials = exec2JSON(`aws sts assume-role \
                                          --profile ${awsProfileName} \
                                          --role-arn ${roleArn} \
                                          --role-session-name ${sessionName}`)

  shell.echo(`Update ~/.aws/credentials as profile ${awsProfileName}`)

  shell.exec(`aws configure set \
             --profile ${awsProfileName} \
              aws_access_key_id ${credentials.Credentials.AccessKeyId}`)

  shell.exec(`aws configure set \
              --profile ${awsProfileName} \
              aws_secret_access_key ${credentials.Credentials.SecretAccessKey}`)

  shell.exec(`aws configure set \
              --profile ${awsProfileName} \
              aws_session_token ${credentials.Credentials.SessionToken}`)

  shell.echo('[OK] done')
}

ssoRefresh()

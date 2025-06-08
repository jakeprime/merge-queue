import * as core from '@actions/core'
import { simpleGit, SimpleGit } from 'simple-git'
import Env from './Env.js'

export default class {
  init = async () => {
    core.info('Initing Git')

    const baseDir = `${Env.workingDir}/merge-queue`
    const git: SimpleGit = simpleGit({ baseDir })
    const logOutput = await git.log()
    const message = logOutput.all[0].message
    core.info(message)
    core.setOutput('message', message)
  }
}

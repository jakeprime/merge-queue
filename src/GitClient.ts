import * as core from '@actions/core'
import { simpleGit, SimpleGit, SimpleGitOptions } from 'simple-git'
import Env from './Env.js'
import { wait } from './wait.js'

export default class {
  init = async () => {
    core.info('Initing Git 1')
    core.info(`GH_TOKEN = (${Env.githubToken.length})`)
    await wait(5000)

    const dir = `${Env.workingDir}/merge-queue`
    // fs.rmSync(dir, { force: true, recursive: true })
    // fs.mkdirSync(dir, { recursive: true })

    const options: Partial<SimpleGitOptions> = { baseDir: dir }

    // when setting all options in a single object
    const git: SimpleGit = simpleGit(options)
    // await git.cwd(dir)
    // await git.init()
    // await git.addRemote(
    //   'origin',
    //   `https://${Env.githubToken}@github.com/jakeprime/merge-subject`
    // )
    // await git.fetch('origin', 'main', { '--depth': 1 })
    // await git.pull('origin', 'main')
    const logOutput = await git.log()
    const message = logOutput.all[0].message
    core.info(message)
    core.setOutput('message', message)
  }
}

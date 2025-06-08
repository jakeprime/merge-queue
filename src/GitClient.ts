import * as core from '@actions/core'
import { simpleGit, SimpleGit, SimpleGitOptions } from 'simple-git'
import fs from 'fs'

export default class {
  init = async () => {
    core.info('Initing Git')

    const dir = '/tmp/git/project'
    fs.rmSync(dir, { force: true, recursive: true })
    fs.mkdirSync(dir, { recursive: true })

    const options: Partial<SimpleGitOptions> = { baseDir: dir }

    // when setting all options in a single object
    const git: SimpleGit = simpleGit(options)
    await git.init()
    await git.addRemote('origin', 'git@github.com:jakeprime/merge-subject.git')
    await git.fetch('origin', 'main', { '--depth': 1 })
    await git.pull('origin', 'main')
    const logOutput = await git.log()
    const message = logOutput.all[0].message
    core.info(message)
    core.setOutput('message', message)
  }
}

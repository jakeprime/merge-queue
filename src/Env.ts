/*
 * Accessor for env vars
 *
 * This abstracts the underlying env var names, allowing us to set other values
 * easily for testing and development. Also a single place to catch missing
 * values and throw an error.
 */

class Env {
  static getValue = (name: string): string => {
    const value = process.env[name]
    if (value === undefined) {
      throw new Error(`Failed to load ${name} from the environment`)
    }

    return value
  }

  public static githubToken: string = this.getValue('GH_TOKEN')
  public static projectRepo: string = this.getValue('PROJECT_REPO')
  public static prNumber: string = this.getValue('PR_NUMBER')
  public static workingDir: string = this.getValue('GITHUB_WORKSPACE')
}

export default Env

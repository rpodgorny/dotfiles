export const BellPlugin = async ({ project, client, $, directory, worktree }) => {
  const sendNotification = async (title, message) => {
    process.stdout.write("\x07")
    //await $`notify-send "${title}" "HOVNO ${message}"`
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.created" && event.sessionID) {
        console.log(`Session created: ${event.sessionID}`)
      }
      if (event.type === "session.idle") {
        await sendNotification("OpenCode", "Generation completed")
      }
    },
    "permission.ask": async (input, output) => {
      const message = `Permission request: ${input.type}`
      await sendNotification("OpenCode", message)
    },
  }
};

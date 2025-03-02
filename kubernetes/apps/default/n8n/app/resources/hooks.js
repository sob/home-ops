const { dirname, resolve } = require('path')
const Layer = require('express/lib/router/layer')
const { issueCookie } = require(resolve(dirname(require.resolve('n8n')), 'auth/jwt'))
const ignoreAuthRegexp = /^\/(assets|healthz|webhook|rest\/oauth2-credential)/
module.exports = {
  n8n: {
    ready: [
      async function ({ app }, config) {
        const { stack } = app._router
        const index = stack.findIndex((l) => l.name === 'cookieParser')
        stack.splice(index + 1, 0, new Layer('/', {
          strict: false,
          end: false
        }, async (req, res, next) => {
          // skip if URL is ignored
          if (ignoreAuthRegexp.test(req.url)) return next()

          // skip if user management is not setup
          if (!config.get('userManagement.isInstanceOwnerSetUp', false)) return next()

          // skip if N8N_FORWARD_AUTH_HEADER is not set
          if (!process.env.N8N_FORWARD_AUTH_HEADER) return next()

          // skip if N8N_FORWARD_AUTH_HEADER is not found
          const email = req.headers[process.env.N8N_FORWARD_AUTH_HEADER.toLowerCase()]
          if (!email) return next()

          // search for user with email
          const user = await this.dbCollections.User.findOneBy({email})
          if (!user) {
            res.statusCode = 401
            res.end(`User ${email} not found, please have an admin invite the user first.`)
            return
          }

          // issue the cookie if all is OK
          issueCookie(res, user)
          return next()
        }))
      },
    ],
  },
}

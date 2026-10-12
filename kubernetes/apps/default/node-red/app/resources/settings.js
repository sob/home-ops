// Node-RED settings. Flows come from the sob/flows project, cloned at startup;
// the editor is behind Tinyauth, so there is no adminAuth here.
module.exports = {
    uiPort: 1880,
    flowFile: "flows.json",
    // The project's credentialSecret is in .config.projects.json, written by the
    // init container from the node-red 1Password item.
    editorTheme: {
        projects: {
            enabled: true,
            workflow: { mode: "manual" },
        },
        tours: false,
    },
    // The palette is package.json in the HelmRelease; editor installs would be
    // lost on restart.
    externalModules: {
        palette: { allowInstall: false },
    },
    functionExternalModules: false,
    exportGlobalContextKeys: false,
    diagnostics: { enabled: false },
    logging: {
        console: { level: "info", metrics: false, audit: false },
    },
};

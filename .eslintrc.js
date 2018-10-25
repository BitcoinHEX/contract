module.exports = {
    parser: 'babel-eslint',
    parserOptions: {
        ecmaFeatures: {
            generators: true,
            experimentalObjectRestSpread: true
        },
        sourceType: 'module',
        allowImportExportEverywhere: false
    },
    extends: [
        'eslint:recommended',
        'plugin:import/errors',
        'plugin:import/warnings',
        'plugin:promise/recommended'
    ],
    plugins: ['compat', 'promise'],
    settings: {
      polyfills: ['fetch', 'promises']
    },
    env: {
        node: true
    },
    globals: {
        __DEV__: true,
        __dirname: true,
        after: true,
        afterAll: true,
        afterEach: true,
        artifacts: true,
        assert: true,
        before: true,
        beforeAll: true,
        beforeEach: true,
        console: true,
        contract: true,
        describe: true,
        expect: true,
        fetch: true,
        global: true,
        it: true,
        module: true,
        process: true,
        Promise: true,
        require: true,
        setTimeout: true,
        test: true,
        xdescribe: true,
        xit: true,
        web3: true
    },
    rules: {
        'compat/compat': 'error',
        'import/first': 'error',
        'import/no-anonymous-default-export': 'error',
        'import/no-unassigned-import': 'error',
        'import/prefer-default-export': 'error',
        'import/no-named-as-default': 'off',
        'import/no-unresolved': 'error',
        'promise/avoid-new': 'off',
        'security/detect-object-injection': 'off',
        'arrow-body-style': 'off',
        'lines-between-class-members': ['error', 'always'],
        'no-console': ['warn', {
            allow: ['assert']
        }],
        'no-shadow': 'error',
        'no-var': 'error',

        'padding-line-between-statements': [
            'error',
            {
                blankLine: 'always',
                prev: 'class',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'do',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: '*',
                next: 'export'
            },
            {
                blankLine: 'always',
                prev: 'for',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'if',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'switch',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'try',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'while',
                next: '*'
            },
            {
                blankLine: 'always',
                prev: 'with',
                next: '*'
            }
        ],
        'prefer-const': 'error'
    }
}

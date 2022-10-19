export default {
    title: 'Terra3',
    base: '/terraform-aws-terra3/',
    description: 'Documentation for Terra3.',
    lastUpdated: true,
    lang: 'en-US',
    themeConfig: {
        // SEE: https://vitepress.vuejs.org/guide/theme-nav AND https://github.com/vuejs/vitepress/blob/main/docs/.vitepress/config.ts
        //logo: '/my-logo.svg',
        //siteTitle: false

        socialLinks: [
            { icon: 'github', link: 'https://github.com/it-objects/terraform-aws-terra3' }
        ],

        editLink: {
            pattern: 'https://github.com/it-objects/terraform-aws-terra3/edit/main/gh-pages/docs/:path',
            text: 'Edit this page on GitHub'
        },

        footer: {
            message: 'Released under the Apache2 License.',
            copyright: 'Copyright © 2022 it-objects GmbH'
        },

        nav: [
          { text: 'IT-Objects', link: 'https://www.it-objects.de/cloud/' },
          /*{
            text: 'Dropdown Menu',
            collapsible: true,
            items: [
              { text: 'Item A', link: '/item-1' },
              { text: 'Item B', link: '/item-2' },
              { text: 'Item C', link: '/item-3' }
            ]
          }*/
        ],
        sidebar: [
            {
              text: 'Guide',
              collapsible: true,
              items: [
                { text: 'Introduction', link: '/introduction' },
                { text: 'Getting Started', link: '/getting-started' },
              ]
            }
          ]
      }
  }

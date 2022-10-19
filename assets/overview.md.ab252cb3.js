import{_ as e,c as t,o as i,d as a}from"./app.f673af1e.js";const o="/assets/62128139.01e1da99.png",f=JSON.parse('{"title":"Overview","description":"","frontmatter":{},"headers":[{"level":2,"title":"What is Terra3","slug":"what-is-terra3","link":"#what-is-terra3","children":[]},{"level":2,"title":"Motivation","slug":"motivation","link":"#motivation","children":[]},{"level":2,"title":"What can I do with this solution?","slug":"what-can-i-do-with-this-solution","link":"#what-can-i-do-with-this-solution","children":[]}],"relativePath":"overview.md","lastUpdated":1666208500000}'),n={name:"overview.md"},r=a('<h1 id="overview" tabindex="-1">Overview <a class="header-anchor" href="#overview" aria-hidden="true">#</a></h1><p>Welcome to Terra3 - An opinionated Terraform module for quickly ramping-up 3-tier solutions in AWS!</p><p>This repository contains a collection of Terraform modules that aim to make it easier and faster for customers to get started with a 3-tier-architecture in <a href="https://aws.amazon.com/" target="_blank" rel="noreferrer">AWS</a>. It can be used to configure and manage a complete stack with</p><ul><li><p>a static website served from S3 and AWS Cloudfront</p></li><li><p>a containerized backend/API running on AWS ECS</p></li><li><p>an AWS RDS MySQL database</p></li></ul><p>The result is a <em>configurable</em>, fully bootstrapped, secure and preconfigured setup with best practices in mind.</p><p><strong>Configurable</strong></p><p>Besides the full-blown setup described above it is possible to simply use certain parts of it:</p><ol><li><p>A static website served from S3 and AWS Cloudfront only: Use this to host your static web application on AWS</p></li><li><p>A containerized backend/API/web page running on AWS ECS only: Use this to host one or more services or APIs as containers in an AWS ECS cluster</p></li></ol><p><strong>Opinionated</strong></p><p>It\u2019s opinionated in the sense that the many decisions involved in such a setup were all made in a reasonable way, suiting the many customers where this is already running in production, where we think that this could also be an ideal starting point for others. Some examples of defaults are</p><ul><li><p>ECS Fargate over ECS with EC2 instances and over EKS</p></li><li><p>Use Cloudfront to serve both static (S3) and dynamic (containers) content</p></li></ul><h2 id="what-is-terra3" tabindex="-1">What is Terra3 <a class="header-anchor" href="#what-is-terra3" aria-hidden="true">#</a></h2><p>In its full-blown version it results in this AWS infrastructure setup:</p><p><img src="'+o+'" alt=""></p><h2 id="motivation" tabindex="-1">Motivation <a class="header-anchor" href="#motivation" aria-hidden="true">#</a></h2><p>Coming soon</p><h2 id="what-can-i-do-with-this-solution" tabindex="-1">What can I do with this solution? <a class="header-anchor" href="#what-can-i-do-with-this-solution" aria-hidden="true">#</a></h2><p>You can use it</p><ul><li><p>as ramp-up to quickly see your website or container run on AWS</p></li><li><p>as base for your next project to skip the nitty gritty grunt work</p></li><li><p>for educational purposes</p></li></ul>',19),s=[r];function l(p,h,c,d,u,m){return i(),t("div",null,s)}const v=e(n,[["render",l]]);export{f as __pageData,v as default};

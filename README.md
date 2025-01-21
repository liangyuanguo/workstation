# ws
## TODO
- [ ] 主要是应用层，都是api
  - [ ] sso，这个包括确保能快速恢复或备份keycloak
  - [ ] cms
  - [ ] mr
- [ ] 可观测
- [ ] 服务器、**域名**过期更换
 
## 遗留
- 数据迁移 0.1
    > 数据库不要更改密码，否则无法迁移，或者迁移时需要更改脚本里写死的密码
  - [X] base
  - [ ] keycloak，暂时无法迁移
  - [X] ~~gateway~~，不用迁移
  - [X] saas-code，依赖包不会迁移，除非在工作目录
  - [X] saas-gitea，git pull/push 测试无问题，域名切换似乎也没问题
  - [X] saas-nextcloud，插件不会迁移

## 功能
- github 存备份，主要是代码
- mini-server 为生产环境
- pc-server   为开发环境
- cloud-server 开发mini-server 的服务给公网或~~vpn用户~~（zerotier太卡了）
- mini-server 数据定期备份到 pc-server


## 其他东西
### 项目管理
KubeVela  可插拔 项目构建 
Dapr 微服务
kong 流量管理

### 玩
opencost
kubevirt  [https://kubevirt.io/user-guide/cluster_admin/installation/](https://kubevirt.io/user-guide/cluster_admin/installation/)
knative 无服务架构  https://knative.k8s.ac.cn/docs/install/yaml-install/serving/install-serving-with-yaml/#verifying-image-signatures


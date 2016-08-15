               UWatch 
                          订阅系统


使用说明：

    I. erlang后端

         1. 启动erlang服务
             ./server/bin/start.sh
 
    II. 前端

        在web/config.yml完善web的地址

        web_addr: 'http://uwatch.nices.net:8889'

        配置是否开启单点登录功能，如果要开启需要在web/config.yml完善下面配置

        sso:
          ref: 'http://login.nices.net:8080/?ref='
          sid: 'http://login.nices.net:8080/info?sid='
        
        依赖PHP用于生成验证码图片（php需要支持ＧＤ库，yum -y install php-gd）

        默认使用$PATH下的php，如果想指定php可以在web/config.yml 中添加 php_path: '/usr/bin/php'

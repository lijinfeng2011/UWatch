    function sendAjaxRequest( Opt ) {
        $.ajax({
            async:       true,
            timeout:     3000,
            type:        'post',  
            url :        Opt['url'],
            dataType:    'json',
            contentType: 'application/json',
            beforeSend:  function()     { Opt['before']();      },
            success:     function(data) { Opt['success'](data); },
            complete:    function()     { Opt['complete']();    },  
            error:       function(XMLHttpRequest, textStatus, errorThrown){ Opt['error'](); }
        });
    }

    function ajaxSubmitProfile( event ) {
        var param = "",
            follows = "",
            invalid = false; 
        var $targetForm = $(event.target).closest('#profile-form');

        $.each ( $targetForm.find('input'), function(n, input) { 
           var type = $(input).attr('type');
           var value = $(input).val();

           if ( type == 'tel' && !value.match( /^0?1[3|4|5|8][0-9]\d{8}$/ ) ) {
               alert ("请输入正确的手机号码");
               invalid = true; return false;
           }

           if ( type == 'tel' || type == 'text' || type == 'number' ) {
               if ( $(input).val().length == 0 && $(input).attr('name') != 'oncaller') { 
                   alert('请填写完整');
                   invalid = true; 
                   return false; 
               }
               var token = param ? '&' : '?';
               token = token + $(input).attr('name') + "=" + $(input).val();
               param = param + token;
	   }
        });

        if ( invalid ) return false;
    
        $.each ( $targetForm.find('option:selected'), function(n, option) {
            if ( follows.length ) { follows = follows + ':' + $(option).val(); }
            else { follows = follows + $(option).val(); }
        });

        if ( follows.length ) { param = param + '&follower=' + follows; }

        var ajaxOpt = {
            url: "/ajaxSetProfile" + param,
            before: showLoader,
            success: success_Profile,
            complete: complete_Profile,
            error: error_Profile
        };

        sendAjaxRequest( ajaxOpt );

        function success_Profile(data) {
            var responseHTML = '';
            if ( data.response === 1 ) {
                responseHTML = '<p>设置失败，请稍后再试!</p>';
            } else if ( data.response === 0 ) {
                responseHTML = '<p>设置成功!</p>';
            }
            $('.profile-mesg').html( responseHTML );
        }
    
        function complete_Profile() {
            $('.profile-mesg').show();
            hideLoader();
        }

        function error_Profile() {
            $('.profile-mesg').html('<p>链接失败，请稍后再试!</p>');
        }

    }

    function triggerAlarm() {
        var check = $('#alarmValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        
        var ajaxOpt = {
            url: "/ajaxSetAlarm?value=" + check,
            before: showLoader,
            success: success_Alarm,
            complete: complete_Alarm,
            error: error_Alarm
        };

        sendAjaxRequest( ajaxOpt );

        function success_Alarm(data) {
            var responseHTML = '';
            if ( data.response === 1 ) {
                responseHTML = '<p>设置失败，请稍后再试!</p>';
            } else if ( data.response === 0 ) {
                responseHTML = '<p>设置成功!</p>';
            }
            $('.profile-mesg').html( responseHTML );
        }

        function complete_Alarm() {
            $('.profile-mesg').show();
            hideLoader();
        }

        function error_Alarm() {
            $('.profile-mesg').html('<p>链接失败，请稍后再试!</p>');
        }
    }

    function triggerFormat() {
        var check = $('#formatValue').hasClass("ui-checkbox-on") ? 'off' : 'on';
        
        var ajaxOpt = {
            url: "/ajaxSetFormat?value=" + check,
            before: showLoader,
            success: success_Format,
            complete: complete_Format,
            error: error_Format
        };

        sendAjaxRequest( ajaxOpt );

        function success_Format(data) {
            var responseHTML = '';
            if ( data.response === 1 ) {
                responseHTML = '<p>设置失败，请稍后再试!</p>';
            } else if ( data.response === 0 ) {
                responseHTML = '<p>设置成功!</p>';
            }
            $('.profile-mesg').html( responseHTML );
        }

        function complete_Format() {
            $('.profile-mesg').show();
            hideLoader();
        }

        function error_Format() {
            $('.profile-mesg').html('<p>链接失败，请稍后再试!</p>');
        }
    }

    function ajaxChangePWD( event ) {
        if ( $('input[name="new-pwd"]').val() != $('input[name="confirm-pwd"]').val() )
        { alert('两次输入新密码不一样'); return false; }
       
        var shouldReturn = false;
                                                                                   
        $.each ( $('input[type="password"]'), function(n, input) {
           var value = $(input).val();

           if ( value.length < 6 ) { alert('长度不小于6位'); shouldReturn = true; return false; }
          
           var reg = new RegExp("[a-zA-Z]");
           if ( !reg.test(value) ) { alert('至少包含一个字母'); shouldReturn = true; return false; }

           reg = new RegExp("[0-9]");
           if ( !reg.test(value) ) { alert('至少包含一个数字'); shouldReturn = true; return false; }

           //reg = new RegExp("((?=[x21-x7e]+)[^A-Za-z0-9])");
           reg = new RegExp("[/#?@]");
           if ( reg.test(value) ) { alert('不能包含/#?@符号'); shouldReturn = true; return false; }
        });

        if ( shouldReturn ) { return false; }

        var old_pwd = $.md5( $('input[name="old-pwd"]').val() );
        var new_pwd = $.md5( $('input[name="new-pwd"]').val() );

        var param = '?old=' + old_pwd + '&new=' + new_pwd;

        var ajaxOpt = {
            url: "/ajaxChangePWD" + param,
            before: showLoader,
            success: success_PWD,
            complete: complete_PWD,
            error: error_PWD
        };

        sendAjaxRequest( ajaxOpt );

        function success_PWD(data) {
            var responseHTML = '';
            if ( data.response === 1 ) {
                responseHTML = '<p>修改失败，稍后再试!</p>';
            } else if ( data.response === 0 ) {
                responseHTML = '<p>修改成功!</p>';
            } else if ( data.response === 2 ) {
                responseHTML = '<p>原始密码错误</p>'
            }
            $('.change-box').html( responseHTML );
        }

        function complete_PWD() {
            $('.change-box').show();
            hideLoader();
        }

        function error_PWD() {
            $('.change-box').html('<p>链接失败，稍后再试!</p>');
        }

    }

    function showLoader() {
        $.mobile.loading('show', {
            text: '数据加载中，请稍候',
            textVisible: true,
            dataType: "json",
            theme: 'a',
            textonly: false,
            html: ""
        });
    }

    function hideLoader() {
        $.mobile.loading('hide');
    }


    function ajaxFormSubmit( event ) {
        var param = ""; var token = "";
        var $targetBox = $(event.target).closest('.subscribe-box');

        $.each ( $targetBox.find('.ui-checkbox'), function(n, item) {
            var name = $(item).find('input[type="checkbox"]').attr("name");
            var value = $(item).find('label').hasClass("ui-checkbox-on") ? 1 : 0;
            if (param) { token = "&" + name + "=" + value; }
            else { token = "?" + name + "=" + value; }
            param = param + token;
        });
        param = param + "&hermesID=" + $targetBox.find('input[name="hermesID"]').val();

        $.ajax({
            timeout:     3000,
            async:       true, 
            dataType:    "json",
            url:         "/ajaxBookSubscribe" + param,
            beforeSend:  showLoader,                                                                
            success:     function ( data ) {
                             var responseHTML = '';
                             if ( data.response === 1 ) {
                                 responseHTML = '<p>订阅失败，稍后再试!</p>';
                             } else if ( data.response === 0 ) {
                                 responseHTML = '<p>订阅成功!</p>';
                             }
                             $targetBox.find('.mesg-box').html( responseHTML );
                         },
            error:       function (XMLHttpRequest, textStatus, errorThrown) {
                             var responseHTML = '<p>链接失败，稍后再试!</p>';
                             $targetBox.find('.mesg-box').html( responseHTML );
                         },
            complete:    function () {
                             $targetBox.find('.mesg-box').show();
                             hideLoader();
                         },
        });
    }

    function ajaxGetSubDetail( target ) {
        var $target = target;
        $.ajax({
            timeout:    2000,
            async:      true,
            dataType:   "json",
            url:        "/ajaxGetSubDetail?group=" + $target.attr("data-name"),
            beforeSend: showLoader,
            success:    function ( data ) {
                           var contentHtml = "";
                           if ( data.subDetail != null && data.subDetail.length > 0 ) {
                              contentHtml = '<div class="subscribe-box"><fieldset data-role="controlgroup">';
                              $.each (data.subDetail, function( n, value ) {
                                 contentHtml = contentHtml + '<label for="' + value.name + '">' + value.name + '</label>';
                                 if ( value.booked ) {
                                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '" checked="checked">';
                                 } else {
                                    contentHtml = contentHtml + '<input type="checkbox" name="' + value.name + '" id="' + value.name + '">';
                                 }
                              });
                              contentHtml = contentHtml + '</fieldset>';
                              contentHtml = contentHtml + '<input type="hidden" name="hermesID" value="' + $target.attr("data-name") + '">';
                              contentHtml = contentHtml + '<input type="button" onclick="ajaxFormSubmit(event)" value="提交选择">';
                              contentHtml = contentHtml + '<div class="mesg-box" style="display:none"></div></div>';
                           } else {
                              contentHtml = "<p>无法获得订阅信息!</p>";
                           }
                           $target.find('.content').html(contentHtml).trigger("create");
                        },
            error:      function( XMLHttpRequest, textStatus, errorThrown ) {
                           var contentHtml = "<p>获取数据有误</p>"
                           $target.find('.content').prepend(contentHtml).trigger("create");
                        },
            complete:   hideLoader,
        });
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

    $(document).ready( function() {
        $(".sub-collapse").collapsible({
            expand: function( event, ui ) {
                ajaxGetSubDetail( $(event.target) );
            }
        });
    });


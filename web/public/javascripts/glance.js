(function($) {
    var timer        = null,
        $selfList    = null,
        $selfPanel   = null,
        $oncallList  = null,
        $oncallPanel = null;

    $(document).on("pagebeforeshow", "#pageGlance", function() {
        $selfList    = $('#selfList');
        $selfPanel   = $('#selfPanel');
        $oncallList  = $('#oncallList');
        $oncallPanel = $('#oncallPanel');

        $(".message-link").unbind('click')
                          .bind('click', getMessageDetail);

        $('#self_link').unbind('click')
                       .bind('click', changeToSelf);

        $('#oncall_link').unbind('click')
                         .bind('click', changeToOncall);

        if ( $oncallPanel.length == 0 ) {
            sessionStorage.setItem('glanceView', 'self');
        } else if (sessionStorage.getItem('glanceView') == null) { 
            sessionStorage.setItem('glanceView', 'self'); }

        if (sessionStorage.getItem('glanceView') == 'self') {
            $('#self_link').addClass('ui-btn-active');
            $oncallPanel.addClass("ui-mobile-viewport-transitioning ui-page hide list-position")
        } else {
            $('#oncall_link').addClass('ui-btn-active');
            $selfPanel.addClass("ui-mobile-viewport-transitioning ui-page hide list-position")
        }

        $selfPanel.unbind('animationend webkitAnimationEnd mozAnimationEnd')
                  .bind('animationend webkitAnimationEnd mozAnimationEnd', function () {
            if ( $selfPanel.attr('class').indexOf(" in")>0 ) {
                 $selfPanel.removeClass()
                           .addClass("ui-mobile-viewport-transitioning ui-page ui-page-active list-static");
            } else {
                 $selfPanel.removeClass()
                           .addClass("ui-mobile-viewport-transitioning ui-page list-position");
            }     
        });

        $oncallPanel.unbind('animationend webkitAnimationEnd mozAnimationEnd')
                    .bind('animationend webkitAnimationEnd mozAnimationEnd', function () {
            if ( $(this).attr('class').indexOf(" in")>0 ) {
                 $(this).removeClass()
                        .addClass("ui-mobile-viewport-transitioning ui-page ui-page-active list-static");
            } else {
                 $(this).removeClass()
                        .addClass("ui-mobile-viewport-transitioning ui-page list-position");
            }
        });

        timer = setTimeout( ajaxGetMessageGroup, 1000 );
    });

    function change(name, reverse, to, from) {
	reverseClass = reverse ? ' reverse' : '';
	$(from).addClass(name + " out" + reverseClass);	
	$(to).addClass(name + " in" + reverseClass);
	$(to).addClass('ui-page-active');
	setTimeout( function(){$(from).addClass('hide');}, 0 );
    }

    function changeToSelf() {
        if (sessionStorage.getItem('glanceView') == 'self') return;

        sessionStorage.setItem('glanceView', 'self');
        $('.mesg-box').hide();   
        change('slide', 1, '#selfPanel', '#oncallPanel');
    }

    function changeToOncall() {
        if (sessionStorage.getItem('glanceView') == 'oncall') return;

        sessionStorage.setItem('glanceView', 'oncall');
        $('.mesg-box').hide();
        change('slide', 0, '#oncallPanel', '#selfPanel');
    }

    $(document).on("pagebeforehide", "#pageGlance", function() {
        if (timer) clearTimeout(timer);
    });

    function getMessageDetail ( event ) {
        var $row = $(event.target).closest('li');
        var $number = $row.find('.ui-li-count');
        $row.removeClass('gary').addClass('gary');
        $row.find('a').removeClass('gary').addClass('gary'); 
        $number.text("0")
               .removeClass('zero-number gary')
               .addClass('zero-number gary');
    }

    function ajaxGetMessageGroup () {
        $.ajax({
           timeout:   3000,
           async:     true,
           dataType:  "json",
           url:       "/ajaxGetMessageGroup?type=" + sessionStorage.getItem('glanceView'),
           success:   function ( data ) {
                         var vType = sessionStorage.getItem('glanceView');
                         var $mainList = vType == 'self' ? $selfList : $oncallList;

                         $mainList.empty();

                         if ( data.mesgGrp != null && data.mesgGrp.length > 0 ) {
                            $('.mesg-box').hide(); 
                            var newHTML = '', oldHTML = '', contentHTML = '';

                            if (vType == 'oncall') {
                                $.each (data.mesgGrp, function( n, mesg ) {
                                    if ( mesg.count == 0 ) {
                                       oldHTML = oldHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=old&id=' + mesg.name + '" class="message-link gary" data-transition="flip">' + mesg.name + '<span class="gary"> (' + mesg.biz + ')</span></a></li>'; 
                                    } else {
                                       newHTML = newHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=new&id=' + mesg.name + '" class="message-link" data-transition="flip">' + mesg.name + '<span class="gary"> (' + mesg.biz + ')</span></a><span class="ui-li-count">' + mesg.count  + '</span></li>'; 
                                    }
                                });
                            } else {
                                $.each (data.mesgGrp, function( n, mesg ) {
                                    if ( mesg.count == 0 ) {
                                       oldHTML = oldHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=old&id=' + mesg.name + '" class="message-link gary" data-transition="flip">' + mesg.name + '</a></li>'; 
                                    } else {
                                       newHTML = newHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=new&id=' + mesg.name + '" class="message-link" data-transition="flip">' + mesg.name + '</a><span class="ui-li-count">' + mesg.count  + '</span></li>'; 
                                    }
                                });
                            }
                            if ( newHTML.length ) contentHTML = newHTML;
                            if ( oldHTML.length ) contentHTML = contentHTML + oldHTML;
                            if ( contentHTML.length )  $mainList.append( contentHTML ); 
                            $mainList.listview('refresh');

                           $(".message-link").unbind('click').bind( 'click', getMessageDetail );
                         } else {
                           var contentHtml = '<p>无最新报警信息!</p>'; 
                           $('.mesg-box').html(contentHtml).show();
                         }
                      },
           error:     function( XMLHttpRequest, textStatus, errorThrown ) {
                          var contentHtml = '<p>网络连接失效，无法获取最新信息!</p>'; 
                          $('.mesg-box').html(contentHtml).show();
                      },
           complete:  function () {
                          timer = setTimeout( ajaxGetMessageGroup, 20000 );
                      },
        });
    }
})(jQuery);

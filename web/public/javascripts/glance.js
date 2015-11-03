(function($) {
    var timer = null;

    $(document).on("pagebeforeshow", "#pageGlance", function() {
        $(".message-link").unbind( 'click' )
                          .bind( 'click', getMessageDetail );
        timer = setTimeout( ajaxGetMessageGroup, 1000 );
    });

    $(document).on("pagebeforehide", "#pageGlance", function() {
        if ( timer ) clearTimeout( timer );
    });

    function getMessageDetail ( event ) {
        var $row = $(event.target).closest('li');
        var $number = $row.find('.ui-li-count');
        $row.removeClass('disable-font').addClass('disable-font');
        $row.find('a').removeClass('disable-font').addClass('disable-font'); 
        $number.text("0")
               .removeClass('zero-number disable-font')
               .addClass('zero-number disable-font');
    }

    function ajaxGetMessageGroup () {
        $.ajax({
           timeout:   3000,
           async:     true,
           dataType:  "json",
           url:       "/ajaxGetMessageGroup",
           success:   function ( data ) {
                         $('#mainList').empty(); 
//                         $('#mainList li').remove();

                         if ( data.mesgGrp != null && data.mesgGrp.length > 0 ) {
                            $('.mesg-box').hide(); 
                            var newHTML = '', oldHTML = '', contentHTML = '',
                                $mainlist = $('#mainList');

                            $.each (data.mesgGrp, function( n, mesg ) {
                                if ( mesg.count == 0 ) {
                                   oldHTML = oldHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=old&id=' + mesg.name + '" class="message-link disable-font" data-transition="flip">' + mesg.name + '</a><span class="ui-li-count disable-font">old</span></li>'; 
                                } else {
                                   newHTML = newHTML + '<li data-icon="false" name="' + mesg.name + '"><a href="/mesgDetail?type=new&id=' + mesg.name + '" class="message-link" data-transition="flip">' + mesg.name + '</a><span class="ui-li-count">' + mesg.count  + '</span></li>'; 
                                }
                            });
                            if ( newHTML.length ) contentHTML = newHTML;
                            if ( oldHTML.length ) contentHTML = contentHTML + oldHTML;
                            if ( contentHTML.length )  $mainlist.append( contentHTML ); 
                            $mainlist.listview('refresh');
                           // $mainlist.trigger('create').listview('refresh');

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

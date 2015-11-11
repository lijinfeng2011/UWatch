$(document).on('mobileinit', function() {
    $.mobile.defaultPageTransition = 'none';
    $.mobile.buttonMarkup.hoverDelay = 10;

    $('.ui-body-c, .ui-overlay-c').css('background', $(".contentc", $.mobile.activePage).css('background'));

//   $.mobile.page.prototype.options.theme = "b";
//   $.mobile.page.prototype.options.headerTheme  = "b";
//   $.mobile.page.prototype.options.contentTheme = "d";
//   $.mobile.page.prototype.options.footerTheme  = "b";

});

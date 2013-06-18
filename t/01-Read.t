use strict;
use warnings;

# I realize that these tests are messy due to unicode file names and
# the optional Mac::PropertyList module.  My goal is to test
# as much functionality as possible, while still allowing the tests
# to pass as long as minimal functionality was present.

use File::Spec qw(catdir catfile);
use Module::Load::Conditional qw[check_install];
use Test::More;

BEGIN { use_ok('WebShortcutUtil::Read') };
require_ok('WebShortcutUtil::Read');

# We do not use these subroutines directly, but let's make sure they are at least exported.
can_ok('WebShortcutUtil::Read', qw(
    read_desktop_shortcut_file
    read_url_shortcut_file
    read_webloc_shortcut_file
    read_website_shortcut_file
));

#########################

use WebShortcutUtil::Read qw(
    shortcut_has_valid_extension
    read_shortcut_file
    read_shortcut_file_url
);

sub _test_read_shortcut {
    my ( $path, $filename, $expected_name, $expected_url ) = @_;
    
    my $full_filename = File::Spec->catfile($path, $filename);
    my $result = read_shortcut_file($full_filename);
    
    my $expected_result = {
        "name", $expected_name,
        "url", $expected_url};
    is_deeply(\$result, \$expected_result, $full_filename);
}


# Note that we check for errors using eval instead of dies_ok.
# This is to avoid having to add a dependency to Test:::Exception.


use utf8;

# Avoid "Wide character in print..." warnings (per http://perldoc.perl.org/Test/More.html)
my $builder = Test::More->builder;
binmode $builder->output, ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output, ":utf8";


diag("Some of the following tests may show warnings.");

# has_valid_extension tests
ok(shortcut_has_valid_extension("file.desktop"), "Valid extention .desktop");
ok(shortcut_has_valid_extension("file.DESKTOP"), "Valid extention .DESKTOP");
ok(shortcut_has_valid_extension("file.url"), "Valid extention .url");
ok(shortcut_has_valid_extension("file.URL"), "Valid extention .URL");
ok(shortcut_has_valid_extension("file.webloc"), "Valid extention .webloc");
ok(shortcut_has_valid_extension("file.WEBLOC"), "Valid extention .WEBLOC");
ok(shortcut_has_valid_extension("file.misleading.desktop"), "Valid extention multiple dots");
ok(!shortcut_has_valid_extension("file.badextension"), "Invalid extention");
ok(!shortcut_has_valid_extension("file"), "Invalid no extention");
ok(!shortcut_has_valid_extension("file.misleading.badextension"), "Invalid extention multiple dots");


# Test missing file
eval { read_shortcut_file("bad_file.desktop") };
like ($@, qr/File.*/, "Read bad desktop file");

eval { read_shortcut_file("bad_file.url") };
like ($@, qr/File.*/, "Read bad url file");

eval { read_shortcut_file("bad_file.bad_extension") };
like ($@, qr/Shortcut file does not have a recognized extension.*/, "Read bad extension");


# Gnome tests
my $gnome_path = File::Spec->catdir("t", "samples", "real", "desktop", "gnome");
_test_read_shortcut($gnome_path, "Google.desktop", "Google", "https://www.google.com/");
_test_read_shortcut($gnome_path, "Yahoo!.desktop", "Yahoo!", "http://www.yahoo.com/");
_test_read_shortcut($gnome_path, File::Spec->catdir("renamed", "Link to Google - renamed.desktop"), "Link to Google - renamed", "https://www.google.com/");


# KDE tests
my $kde_path = File::Spec->catdir("t", "samples", "real", "desktop", "kde");
_test_read_shortcut($kde_path, "http___japan.zdnet.com_.desktop", "http___japan.zdnet.com_", "http://japan.zdnet.com/");
_test_read_shortcut($kde_path, "https___www.google.com_.desktop", "https___www.google.com_", "https://www.google.com/");
_test_read_shortcut($kde_path, "http___www.microsoft.com_sv-se_default.aspx.desktop", "http___www.microsoft.com_sv-se_default.aspx", "http://www.microsoft.com/sv-se/default.aspx");
_test_read_shortcut($kde_path, "http___www.myspace.com_.desktop", "http___www.myspace.com_", "http://www.myspace.com/");
_test_read_shortcut($kde_path, "http___www.yahoo.com_.desktop", "http___www.yahoo.com_", "http://www.yahoo.com/");
_test_read_shortcut($kde_path, "http___cn.yahoo.com_.desktop", "http___cn.yahoo.com_", "http://cn.yahoo.com/");
_test_read_shortcut($kde_path, "http___xn--fet810g.xn--fiqs8s_.desktop", "http___xn--fet810g.xn--fiqs8s_", "http://xn--fet810g.xn--fiqs8s/");
_test_read_shortcut($kde_path, "http___www.baidu.com_.desktop", "http___www.baidu.com_", "http://www.baidu.com/");


# Desktop fake tests
my $desktop_fake_path = File::Spec->catdir("t", "samples", "fake", "desktop");

_test_read_shortcut($desktop_fake_path, "CommentsAndBlankLines.desktop", "CommentsAndBlankLines", "https://www.google.com/");

eval { read_shortcut_file(File::Spec->catdir ($desktop_fake_path, "Empty.desktop")) };
like ($@, qr/Desktop Entry group not found.*/, "Empty desktop");

eval { read_shortcut_file(File::Spec->catdir ($desktop_fake_path, "GarbledHeader.desktop")) };
like ($@, qr/Desktop Entry group not found.*/, "Garbled header desktop");

_test_read_shortcut($desktop_fake_path, "GarbledEntry.desktop", "GarbledEntry", "https://www.google.com/");

eval { read_shortcut_file(File::Spec->catdir ($desktop_fake_path, "HeaderOnly.desktop")) };
like ($@, qr/URL not found in file.*/, "HeaderOnly.desktop");

eval { read_shortcut_file(File::Spec->catdir ($desktop_fake_path, "ApplicationType.desktop")) };
like ($@, qr/URL not found in file.*/, "Application desktop");

_test_read_shortcut($desktop_fake_path, "LotsOfWhitespace.desktop", "LotsOfWhitespace", "https://www.google.com/");


# URL tests: Chrome
my $url_chrome_path = File::Spec->catdir("t", "samples", "real", "url", "Chrome");
_test_read_shortcut($url_chrome_path, "Google.url", "Google", "https://www.google.com/");
_test_read_shortcut($url_chrome_path, "Myspace - Social Entertainment.url", "Myspace - Social Entertainment", "http://www.myspace.com/");
_test_read_shortcut($url_chrome_path, "Yahoo!.url", "Yahoo!", "http://www.yahoo.com/");

# URL tests: Firefox (note that a couple of the URLs contain special ASCII characters (not UTF8) and need to use Perl's \xNN encoding mechanism)
my $url_firefox_path = File::Spec->catdir("t", "samples", "real", "url", "Firefox");
_test_read_shortcut($url_firefox_path, "Google.URL", "Google", "https://www.google.com/");
_test_read_shortcut($url_firefox_path, "Myspace Social Entertainment.URL", "Myspace Social Entertainment", "http://www.myspace.com/");
_test_read_shortcut($url_firefox_path, "Yahoo!.URL", "Yahoo!", "http://www.yahoo.com/");

# URL tests: Internet Explorer
my $url_ie_path = File::Spec->catdir("t", "samples", "real", "url", "IE");
_test_read_shortcut($url_ie_path, "cn.yahoo.com.url", "cn.yahoo.com", "http://cn.yahoo.com/");
_test_read_shortcut($url_ie_path, "Google.url", "Google", "https://www.google.com/");
_test_read_shortcut($url_ie_path, "Myspace  Social Entertainment.url", "Myspace  Social Entertainment", "http://www.myspace.com/");
_test_read_shortcut($url_ie_path, "Yahoo!.url", "Yahoo!", "http://www.yahoo.com/");

# URL tests: Hypothetical
my $url_fake_path = File::Spec->catdir("t", "samples", "fake", "url");

_test_read_shortcut($url_fake_path, "LotsOfWhitespace.url", "LotsOfWhitespace", "https://www.google.com/");

_test_read_shortcut($url_fake_path, "GarbledEntry.url", "GarbledEntry", "https://www.google.com/");

eval { read_shortcut_file(File::Spec->catdir ($url_fake_path, "HeaderOnly.url")) };
like ($@, qr/URL not found in file.*/, "Url not found");


# Website tests: IE9
my $website_ie9_path = File::Spec->catdir("t", "samples", "real", "website", "IE9");
_test_read_shortcut($website_ie9_path, "Google.website", "Google", "https://www.google.com/");
_test_read_shortcut($website_ie9_path, "Microsoft Corporation.website", "Microsoft Corporation", "http://www.microsoft.com/sv-se/default.aspx");
_test_read_shortcut($website_ie9_path, "Myspace  Social Entertainment.website", "Myspace  Social Entertainment", "http://www.myspace.com/");
_test_read_shortcut($website_ie9_path, "Yahoo!.website", "Yahoo!", "http://www.yahoo.com/");

# Website tests: IE10
my $website_ie10_path = File::Spec->catdir("t", "samples", "real", "website", "IE10");
_test_read_shortcut($website_ie10_path, "Google.website", "Google", "https://www.google.com/");
_test_read_shortcut($website_ie10_path, "Microsoft Corporation.website", "Microsoft Corporation", "http://www.microsoft.com/sv-se/default.aspx");
_test_read_shortcut($website_ie10_path, "Myspace  Social Entertainment.website", "Myspace  Social Entertainment", "http://www.myspace.com/");
_test_read_shortcut($website_ie10_path, "Yahoo!.website", "Yahoo!", "http://www.yahoo.com/");


# Test read_shortcut_file_url
is(read_shortcut_file_url(File::Spec->catfile($gnome_path, "Google.desktop")), "https://www.google.com/", "read_shortcut_file_url");


TODO: {
    local $TODO = "Some file systems/operating systems do not handle unicode characters in filenames well.  Need to better manage these tests.";

    eval {
        # Gnome tests
        _test_read_shortcut($gnome_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.desktop", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
        _test_read_shortcut($gnome_path, "Myspace | Social Entertainment.desktop", "Myspace | Social Entertainment", "http://www.myspace.com/");
        _test_read_shortcut($gnome_path, "Microsoft Sverige | Enheter och tjänster.desktop", "Microsoft Sverige | Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
        _test_read_shortcut($gnome_path, "sverige - Sök på Google.desktop", "sverige - Sök på Google", "http://www.google.se/#sclient=tablet-gws&hl=sv&tbo=d&q=sverige&oq=sveri&gs_l=tablet-gws.1.1.0l3.13058.15637.28.17682.5.2.2.1.1.0.143.243.0j2.2.0...0.0...1ac.1.xX8iu4i9hYM&pbx=1&fp=1&bpcl=40096503&biw=1280&bih=800&bav=on.2,or.r_gc.r_pw.r_qf.&cad=b");
        _test_read_shortcut($gnome_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.desktop", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.中国政府.政务.cn/");
        _test_read_shortcut($gnome_path, "中国雅虎首页.desktop", "中国雅虎首页", "http://cn.yahoo.com/");
        _test_read_shortcut($gnome_path, "导航.中国.desktop", "导航.中国", "http://导航.中国/");
        _test_read_shortcut($gnome_path, "百度一下，你就知道.desktop", "百度一下，你就知道", "http://www.baidu.com/");

        # KDE tests
        _test_read_shortcut($kde_path, "http___www.中国政府.政务.cn_.desktop", "http___www.中国政府.政务.cn_", "http://www.xn--fiqs8sirgfmh.xn--zfr164b.cn/");

        # URL tests: Chrome
        _test_read_shortcut($url_chrome_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.url", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
        _test_read_shortcut($url_chrome_path, "Microsoft Sverige - Enheter och tjänster.url", "Microsoft Sverige - Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
        _test_read_shortcut($url_chrome_path, "sverige - Sök på Google.url", "sverige - Sök på Google", "http://www.google.se/#sclient=tablet-gws&hl=sv&tbo=d&q=sverige&oq=sveri&gs_l=tablet-gws.1.1.0l3.13058.15637.28.17682.5.2.2.1.1.0.143.243.0j2.2.0...0.0...1ac.1.xX8iu4i9hYM&pbx=1&fp=1&bpcl=40096503&biw=1280&bih=800&bav=on.2,or.r_gc.r_pw.r_qf.&cad=b");
        _test_read_shortcut($url_chrome_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.url", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.xn--fiqs8sirgfmh.xn--zfr164b.cn/");
        _test_read_shortcut($url_chrome_path, "中国雅虎首页.url", "中国雅虎首页", "http://cn.yahoo.com/");
        _test_read_shortcut($url_chrome_path, "导航.中国.url", "导航.中国", "http://xn--fet810g.xn--fiqs8s/");
        _test_read_shortcut($url_chrome_path, "百度一下，你就知道.url", "百度一下，你就知道", "http://www.baidu.com/");

        # URL tests: Firefox (note that a couple of the URLs contain special ASCII characters (not UTF8) and need to use Perl's \xNN encoding mechanism)
        _test_read_shortcut($url_firefox_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.URL", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
        _test_read_shortcut($url_firefox_path, "Microsoft Sverige Enheter och tjänster.URL", "Microsoft Sverige Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
        _test_read_shortcut($url_firefox_path, "sverige - Sök på Google.URL", "sverige - Sök på Google", "http://www.google.se/#sclient=tablet-gws&hl=sv&tbo=d&q=sverige&oq=sveri&gs_l=tablet-gws.1.1.0l3.13058.15637.28.17682.5.2.2.1.1.0.143.243.0j2.2.0...0.0...1ac.1.xX8iu4i9hYM&pbx=1&fp=1&bpcl=40096503&biw=1280&bih=800&bav=on.2,or.r_gc.r_pw.r_qf.&cad=b");
        _test_read_shortcut($url_firefox_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.URL", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.-\xFD?\x9C.?\xA1.cn/");
        _test_read_shortcut($url_firefox_path, "中国雅虎首页.URL", "中国雅虎首页", "http://cn.yahoo.com/");
        _test_read_shortcut($url_firefox_path, "导航.中国.URL", "导航.中国", "http://\xFC*.-\xFD/");
        _test_read_shortcut($url_firefox_path, "百度一下，你就知道.URL", "百度一下，你就知道", "http://www.baidu.com/");

        # URL tests: Internet Explorer
        _test_read_shortcut($url_ie_path, "Microsoft Sverige  Enheter och tjänster.url", "Microsoft Sverige  Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
        _test_read_shortcut($url_ie_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.url", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.中国政府.政务.cn/");
        _test_read_shortcut($url_ie_path, "百度一下，你就知道.url", "百度一下，你就知道", "http://www.baidu.com/");

        # Website tests: IE9
        _test_read_shortcut($website_ie9_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.website", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
        _test_read_shortcut($website_ie9_path, "sverige - Sök på Google.website", "sverige - Sök på Google", "http://www.google.se/");
        _test_read_shortcut($website_ie9_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.website", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.中国政府.政务.cn/");
        _test_read_shortcut($website_ie9_path, "中国雅虎首页.website", "中国雅虎首页", "http://cn.yahoo.com/");
        _test_read_shortcut($website_ie9_path, "导航.中国.website", "导航.中国", "http://导航.中国/");
        _test_read_shortcut($website_ie9_path, "百度一下，你就知道.website", "百度一下，你就知道", "http://www.baidu.com/");

        # Website tests: IE10
        _test_read_shortcut($website_ie10_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.website", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
        _test_read_shortcut($website_ie10_path, "sverige - Sök på Google.website", "sverige - Sök på Google", "http://www.google.se/");
        _test_read_shortcut($website_ie10_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.website", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.中国政府.政务.cn/");
        _test_read_shortcut($website_ie10_path, "中国雅虎首页.website", "中国雅虎首页", "http://cn.yahoo.com/");
        _test_read_shortcut($website_ie10_path, "导航.中国.website", "导航.中国", "http://导航.中国/");
        _test_read_shortcut($website_ie10_path, "百度一下，你就知道.website", "百度一下，你就知道", "http://www.baidu.com/");
    } or fail("Some tests died while accessing files named with unicode characters.");
}


SKIP: {
    if(!defined(check_install( module => 'Mac::PropertyList' ))) {
        skip ("Mac::PropertyList not installed.  Cannot test webloc functionality unless this package is installed.", 0);
    }

    # Binary plist tests
    my $webloc_bin_path = File::Spec->catdir("t", "samples", "real", "webloc", "binary");
    my $webloc_bin_percent_path = File::Spec->catdir($webloc_bin_path, "percent_encoded");
    _test_read_shortcut($webloc_bin_path, "Google.webloc", "Google", "https://www.google.com/");
    _test_read_shortcut($webloc_bin_path, "Yahoo!.webloc", "Yahoo!", "http://www.yahoo.com/");

    # XML plist tests
    my $webloc_xml_path = File::Spec->catdir("t", "samples", "real", "webloc", "xml");
    my $webloc_xml_percent_path = File::Spec->catdir($webloc_xml_path, "percent_encoded");
    _test_read_shortcut($webloc_xml_path, "Google.webloc", "Google", "https://www.google.com/");
    _test_read_shortcut($webloc_xml_path, "Yahoo!.webloc", "Yahoo!", "http://www.yahoo.com/");

    # Missing file
    eval { read_shortcut_file("bad_file.webloc") };
    like ($@, qr/parse_plist_file: file.*/, "Read bad webloc file");

    # Plist Error Test
    my $webloc_xml_fake_path = File::Spec->catdir("t", "samples", "fake", "webloc", "xml");

    eval { read_shortcut_file(File::Spec->catdir ($webloc_xml_fake_path, "MissingDictionary.webloc")) } ;
    like ($@, qr/Webloc plist file does not contain a dictionary.*/);

    eval { read_shortcut_file(File::Spec->catdir ($webloc_xml_fake_path, "MissingUrl.webloc")) } ;
    like ($@, qr/Webloc plist file does not contain a URL.*/);

    TODO: {
        local $TODO = "Some file systems/operating systems do not handle unicode characters in filenames well.  Need to better manage these tests.";

        eval {
            # Binary plist tests
            _test_read_shortcut($webloc_bin_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.webloc", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
            _test_read_shortcut($webloc_bin_path, "Microsoft Sverige  Enheter och tjänster.webloc", "Microsoft Sverige  Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
            _test_read_shortcut($webloc_bin_path, "Myspace  Social Entertainment.webloc", "Myspace  Social Entertainment", "http://www.myspace.com/");
            _test_read_shortcut($webloc_bin_path, "sverige - Sök på Google.webloc", "sverige - Sök på Google", "http://www.google.se/#sclient=tablet-gws&hl=sv&tbo=d&q=sverige&oq=sveri&gs_l=tablet-gws.1.1.0l3.13058.15637.28.17682.5.2.2.1.1.0.143.243.0j2.2.0...0.0...1ac.1.xX8iu4i9hYM&pbx=1&fp=1&bpcl=40096503&biw=1280&bih=800&bav=on.2,or.r_gc.r_pw.r_qf.&cad=b");
            _test_read_shortcut($webloc_bin_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.webloc", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.xn--fiqs8sirgfmh.xn--zfr164b.cn/");
            _test_read_shortcut($webloc_bin_path, "中国雅虎首页.webloc", "中国雅虎首页", "http://cn.yahoo.com/");
            _test_read_shortcut($webloc_bin_path, "导航.中国.webloc", "导航.中国", "http://xn--fet810g.xn--fiqs8s/");
            _test_read_shortcut($webloc_bin_path, "百度一下，你就知道.webloc", "百度一下，你就知道", "http://www.baidu.com/");
            _test_read_shortcut($webloc_bin_percent_path, "导航.中国.webloc", "导航.中国", "http://%E5%AF%BC%E8%88%AA.%E4%B8%AD%E5%9B%BD/");

            # XML plist tests
            _test_read_shortcut($webloc_xml_path, "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan.webloc", "CIOとITマネージャーの課題を解決するオンラインメディア - ZDNet Japan", "http://japan.zdnet.com/");
            _test_read_shortcut($webloc_xml_path, "Microsoft Sverige  Enheter och tjänster.webloc", "Microsoft Sverige  Enheter och tjänster", "http://www.microsoft.com/sv-se/default.aspx");
            _test_read_shortcut($webloc_xml_path, "Myspace  Social Entertainment.webloc", "Myspace  Social Entertainment", "http://www.myspace.com/");
            _test_read_shortcut($webloc_xml_path, "sverige - Sök på Google.webloc", "sverige - Sök på Google", "http://www.google.se/#sclient=tablet-gws&hl=sv&tbo=d&q=sverige&oq=sveri&gs_l=tablet-gws.1.1.0l3.13058.15637.28.17682.5.2.2.1.1.0.143.243.0j2.2.0...0.0...1ac.1.xX8iu4i9hYM&pbx=1&fp=1&bpcl=40096503&biw=1280&bih=800&bav=on.2,or.r_gc.r_pw.r_qf.&cad=b");
            _test_read_shortcut($webloc_xml_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.webloc", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.xn--fiqs8sirgfmh.xn--zfr164b.cn/");
            _test_read_shortcut($webloc_xml_path, "中国雅虎首页.webloc", "中国雅虎首页", "http://cn.yahoo.com/");
            _test_read_shortcut($webloc_xml_path, "导航.中国.webloc", "导航.中国", "http://xn--fet810g.xn--fiqs8s/");
            _test_read_shortcut($webloc_xml_path, "百度一下，你就知道.webloc", "百度一下，你就知道", "http://www.baidu.com/");
            _test_read_shortcut($webloc_xml_percent_path, "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn.webloc", "www.ÖÐ¹úÕþ¸®.ÕþÎñ.cn", "http://www.%E4%B8%AD%E5%9B%BD%E6%94%BF%E5%BA%9C.%E6%94%BF%E5%8A%A1.cn/");
            _test_read_shortcut($webloc_xml_percent_path, "导航.中国.webloc", "导航.中国", "http://%E5%AF%BC%E8%88%AA.%E4%B8%AD%E5%9B%BD/");
        } or fail("Some tests died while accessing files named with unicode characters.");
    }
}

done_testing;

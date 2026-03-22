#ifdef __APPLE__

#import <Cocoa/Cocoa.h>

#include <foobar2000/SDK/foobar2000.h>

#include "foo_prefs.h"
#include "foo_vgmstream.h"

static NSString* to_ns_string(const std::string& value) {
    return [NSString stringWithUTF8String:value.c_str()];
}

@interface VGMStreamFlippedView : NSView
@end

@implementation VGMStreamFlippedView
- (BOOL)isFlipped {
    return YES;
}
@end

@interface VGMStreamPreferencesViewController : NSViewController <NSTextFieldDelegate>
@property (nonatomic) NSScrollView* scrollView;
@property (nonatomic) VGMStreamFlippedView* contentView;
@property (nonatomic) NSStackView* mainStack;
@property (nonatomic) NSSegmentedControl* loopModeControl;
@property (nonatomic) NSTextField* loopCountField;
@property (nonatomic) NSTextField* fadeLengthField;
@property (nonatomic) NSTextField* fadeDelayField;
@property (nonatomic) NSTextField* downmixChannelsField;
@property (nonatomic) NSButton* disableSubsongsCheckbox;
@property (nonatomic) NSButton* tagfileDisableCheckbox;
@property (nonatomic) NSButton* overrideTitleCheckbox;
@property (nonatomic) NSButton* extsUnknownCheckbox;
@property (nonatomic) NSButton* extsCommonCheckbox;
@end

@implementation VGMStreamPreferencesViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    return self;
}

- (void)loadView {
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 640, 420)];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.drawsBackground = NO;

    self.contentView = [[VGMStreamFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 640, 420)];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = self.contentView;

    self.mainStack = [[NSStackView alloc] init];
    self.mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.mainStack.alignment = NSLayoutAttributeLeading;
    self.mainStack.spacing = 14.0;

    [self.contentView addSubview:self.mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:20.0],
        [self.mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [self.mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [self.mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20.0],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],
    ]];

    NSTextField* titleLabel = [NSTextField labelWithString:@"Playback"];
    titleLabel.font = [NSFont boldSystemFontOfSize:13.0];
    [self.mainStack addArrangedSubview:titleLabel];

    self.loopModeControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0, 0, 240, 28)];
    self.loopModeControl.segmentCount = 3;
    [self.loopModeControl setLabel:@"Normal" forSegment:0];
    [self.loopModeControl setLabel:@"Ignore" forSegment:1];
    [self.loopModeControl setLabel:@"Forever" forSegment:2];
    self.loopModeControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.loopModeControl.target = self;
    self.loopModeControl.action = @selector(onLoopModeChanged:);
    NSStackView* loopModeRow = [self labeledRowWithTitle:@"Loop handling" control:self.loopModeControl];
    [self.mainStack addArrangedSubview:loopModeRow];

    self.loopCountField = [self makeTextField];
    [self.mainStack addArrangedSubview:[self labeledRowWithTitle:@"Loop count" control:self.loopCountField]];

    self.fadeLengthField = [self makeTextField];
    [self.mainStack addArrangedSubview:[self labeledRowWithTitle:@"Fade length" control:self.fadeLengthField]];

    self.fadeDelayField = [self makeTextField];
    [self.mainStack addArrangedSubview:[self labeledRowWithTitle:@"Fade delay" control:self.fadeDelayField]];

    self.downmixChannelsField = [self makeTextField];
    [self.mainStack addArrangedSubview:[self labeledRowWithTitle:@"Downmix channels" control:self.downmixChannelsField]];

    self.disableSubsongsCheckbox = [self makeCheckbox:@"Disable subsongs" action:@selector(onDisableSubsongsChanged:)];
    [self.mainStack addArrangedSubview:self.disableSubsongsCheckbox];

    NSTextField* metadataLabel = [NSTextField labelWithString:@"Metadata"];
    metadataLabel.font = [NSFont boldSystemFontOfSize:13.0];
    [self.mainStack addArrangedSubview:metadataLabel];

    self.tagfileDisableCheckbox = [self makeCheckbox:@"Disable !tags.m3u lookup" action:@selector(onTagfileDisableChanged:)];
    [self.mainStack addArrangedSubview:self.tagfileDisableCheckbox];

    self.overrideTitleCheckbox = [self makeCheckbox:@"Do not export TITLE tag" action:@selector(onOverrideTitleChanged:)];
    [self.mainStack addArrangedSubview:self.overrideTitleCheckbox];

    NSTextField* filetypesLabel = [NSTextField labelWithString:@"File detection"];
    filetypesLabel.font = [NSFont boldSystemFontOfSize:13.0];
    [self.mainStack addArrangedSubview:filetypesLabel];

    self.extsUnknownCheckbox = [self makeCheckbox:@"Accept uncommon extensions" action:@selector(onExtsUnknownChanged:)];
    [self.mainStack addArrangedSubview:self.extsUnknownCheckbox];

    self.extsCommonCheckbox = [self makeCheckbox:@"Accept common extensions" action:@selector(onExtsCommonChanged:)];
    [self.mainStack addArrangedSubview:self.extsCommonCheckbox];

    NSButton* resetButton = [NSButton buttonWithTitle:@"Restore Defaults" target:self action:@selector(onResetDefaults:)];
    [self.mainStack addArrangedSubview:resetButton];

    self.view = self.scrollView;
    [self reloadFromPreferences];
    [self updateContentLayout];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [self updateContentLayout];
}

- (void)updateContentLayout {
    if (self.mainStack == nil || self.contentView == nil || self.scrollView == nil)
        return;

    [self.contentView layoutSubtreeIfNeeded];

    CGFloat width = NSWidth(self.scrollView.contentView.bounds);
    if (width <= 0) {
        width = 640.0;
    }

    NSSize fittingSize = [self.mainStack fittingSize];
    CGFloat height = fittingSize.height + 40.0;
    if (height < NSHeight(self.scrollView.contentView.bounds)) {
        height = NSHeight(self.scrollView.contentView.bounds);
    }

    self.contentView.frame = NSMakeRect(0, 0, width, height);
}

- (NSTextField*)makeTextField {
    NSTextField* field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.delegate = self;
    [field.widthAnchor constraintEqualToConstant:140.0].active = YES;
    return field;
}

- (NSButton*)makeCheckbox:(NSString*)title action:(SEL)action {
    NSButton* checkbox = [NSButton checkboxWithTitle:title target:self action:action];
    checkbox.translatesAutoresizingMaskIntoConstraints = NO;
    return checkbox;
}

- (NSStackView*)labeledRowWithTitle:(NSString*)title control:(NSView*)control {
    NSTextField* label = [NSTextField labelWithString:title];
    label.alignment = NSTextAlignmentRight;
    [label.widthAnchor constraintEqualToConstant:140.0].active = YES;

    NSStackView* row = [[NSStackView alloc] init];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeFirstBaseline;
    row.spacing = 12.0;
    [row addArrangedSubview:label];
    [row addArrangedSubview:control];
    return row;
}

- (void)reloadFromPreferences {
    if (vgmstream_prefs::get_ignore_loop()) {
        self.loopModeControl.selectedSegment = 1;
    } else if (vgmstream_prefs::get_loop_forever()) {
        self.loopModeControl.selectedSegment = 2;
    } else {
        self.loopModeControl.selectedSegment = 0;
    }

    self.loopCountField.stringValue = to_ns_string(vgmstream_prefs::get_loop_count_text());
    self.fadeLengthField.stringValue = to_ns_string(vgmstream_prefs::get_fade_length_text());
    self.fadeDelayField.stringValue = to_ns_string(vgmstream_prefs::get_fade_delay_text());
    self.downmixChannelsField.stringValue = to_ns_string(vgmstream_prefs::get_downmix_channels_text());

    self.disableSubsongsCheckbox.state = vgmstream_prefs::get_disable_subsongs() ? NSControlStateValueOn : NSControlStateValueOff;
    self.tagfileDisableCheckbox.state = vgmstream_prefs::get_tagfile_disable() ? NSControlStateValueOn : NSControlStateValueOff;
    self.overrideTitleCheckbox.state = vgmstream_prefs::get_override_title() ? NSControlStateValueOn : NSControlStateValueOff;
    self.extsUnknownCheckbox.state = vgmstream_prefs::get_exts_unknown_on() ? NSControlStateValueOn : NSControlStateValueOff;
    self.extsCommonCheckbox.state = vgmstream_prefs::get_exts_common_on() ? NSControlStateValueOn : NSControlStateValueOff;
    [self updateContentLayout];
}

- (void)showValidationError:(const std::string&)error {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Invalid setting";
    alert.informativeText = to_ns_string(error);
    if (self.view.window) {
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

- (void)markFieldValid:(NSTextField*)field {
    field.textColor = [NSColor controlTextColor];
}

- (void)markFieldInvalid:(NSTextField*)field {
    field.textColor = [NSColor systemRedColor];
}

- (void)applyLoopModeSelection {
    NSInteger selected = self.loopModeControl.selectedSegment;
    vgmstream_prefs::set_ignore_loop(selected == 1);
    vgmstream_prefs::set_loop_forever(selected == 2);
    [self reloadFromPreferences];
}

- (BOOL)applyLoopCountField:(BOOL)showError {
    std::string error;
    if (!vgmstream_prefs::set_loop_count_text(self.loopCountField.stringValue.UTF8String, error)) {
        [self markFieldInvalid:self.loopCountField];
        if (showError) {
            [self reloadFromPreferences];
            [self showValidationError:error];
        }
        return NO;
    }
    [self markFieldValid:self.loopCountField];
    return YES;
}

- (BOOL)applyFadeLengthField:(BOOL)showError {
    std::string error;
    if (!vgmstream_prefs::set_fade_length_text(self.fadeLengthField.stringValue.UTF8String, error)) {
        [self markFieldInvalid:self.fadeLengthField];
        if (showError) {
            [self reloadFromPreferences];
            [self showValidationError:error];
        }
        return NO;
    }
    [self markFieldValid:self.fadeLengthField];
    return YES;
}

- (BOOL)applyFadeDelayField:(BOOL)showError {
    std::string error;
    if (!vgmstream_prefs::set_fade_delay_text(self.fadeDelayField.stringValue.UTF8String, error)) {
        [self markFieldInvalid:self.fadeDelayField];
        if (showError) {
            [self reloadFromPreferences];
            [self showValidationError:error];
        }
        return NO;
    }
    [self markFieldValid:self.fadeDelayField];
    return YES;
}

- (BOOL)applyDownmixChannelsField:(BOOL)showError {
    std::string error;
    if (!vgmstream_prefs::set_downmix_channels_text(self.downmixChannelsField.stringValue.UTF8String, error)) {
        [self markFieldInvalid:self.downmixChannelsField];
        if (showError) {
            [self reloadFromPreferences];
            [self showValidationError:error];
        }
        return NO;
    }
    [self markFieldValid:self.downmixChannelsField];
    return YES;
}

- (void)controlTextDidChange:(NSNotification*)notification {
    id object = notification.object;
    if (object == self.loopCountField) {
        [self applyLoopCountField:NO];
    } else if (object == self.fadeLengthField) {
        [self applyFadeLengthField:NO];
    } else if (object == self.fadeDelayField) {
        [self applyFadeDelayField:NO];
    } else if (object == self.downmixChannelsField) {
        [self applyDownmixChannelsField:NO];
    }
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
    id object = notification.object;
    if (object == self.loopCountField) {
        [self applyLoopCountField:YES];
    } else if (object == self.fadeLengthField) {
        [self applyFadeLengthField:YES];
    } else if (object == self.fadeDelayField) {
        [self applyFadeDelayField:YES];
    } else if (object == self.downmixChannelsField) {
        [self applyDownmixChannelsField:YES];
    }
}

- (void)onLoopModeChanged:(id)sender {
    (void)sender;
    [self applyLoopModeSelection];
}

- (void)onDisableSubsongsChanged:(id)sender {
    vgmstream_prefs::set_disable_subsongs(((NSButton*)sender).state == NSControlStateValueOn);
    [self reloadFromPreferences];
}

- (void)onTagfileDisableChanged:(id)sender {
    vgmstream_prefs::set_tagfile_disable(((NSButton*)sender).state == NSControlStateValueOn);
    [self reloadFromPreferences];
}

- (void)onOverrideTitleChanged:(id)sender {
    vgmstream_prefs::set_override_title(((NSButton*)sender).state == NSControlStateValueOn);
    [self reloadFromPreferences];
}

- (void)onExtsUnknownChanged:(id)sender {
    vgmstream_prefs::set_exts_unknown_on(((NSButton*)sender).state == NSControlStateValueOn);
    [self reloadFromPreferences];
}

- (void)onExtsCommonChanged:(id)sender {
    vgmstream_prefs::set_exts_common_on(((NSButton*)sender).state == NSControlStateValueOn);
    [self reloadFromPreferences];
}

- (void)onResetDefaults:(id)sender {
    (void)sender;
    vgmstream_prefs::reset_defaults();
    [self reloadFromPreferences];
}

@end

namespace {
class vgmstream_preferences_page_mac : public preferences_page {
public:
    service_ptr instantiate() override {
        return fb2k::wrapNSObject([VGMStreamPreferencesViewController new]);
    }

    const char* get_name() override {
        return input_vgmstream::g_get_name();
    }

    GUID get_guid() override {
        return input_vgmstream::g_get_preferences_guid();
    }

    GUID get_parent_guid() override {
        return preferences_page::guid_input;
    }
};

FB2K_SERVICE_FACTORY(vgmstream_preferences_page_mac);
}

#endif

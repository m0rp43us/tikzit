/*
 * Copyright 2011  Alex Merry <dev@randomguy3.me.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "NodeStylesPalette.h"

#import "NodeStyleSelector.h"
#import "NodeStyleEditor.h"
#import "StyleManager.h"
#import "TikzDocument.h"

// {{{ Internal interfaces
// {{{ GTK+ Callbacks
static void add_style_button_cb (GtkButton *widget, NodeStylesPalette *palette);
static void remove_style_button_cb (GtkButton *widget, NodeStylesPalette *palette);
static void apply_style_button_cb (GtkButton *widget, NodeStylesPalette *palette);
static void clear_style_button_cb (GtkButton *widget, NodeStylesPalette *palette);
// }}}
// {{{ Notifications

@interface NodeStylesPalette (Notifications)
- (void) selectedStyleChanged:(NSNotification*)notification;
- (void) nodeSelectionChanged:(NSNotification*)n;
@end

// }}}
// {{{ Private

@interface NodeStylesPalette (Private)
- (void) updateButtonState;
- (void) removeSelectedStyle;
- (void) applySelectedStyle;
- (void) clearSelectedStyle;
@end

// }}}
// }}}
// {{{ API

@implementation NodeStylesPalette

@synthesize widget=palette;

- (id) init {
    [self release];
    self = nil;
    return nil;
}

- (id) initWithManager:(StyleManager*)m {
    self = [super init];

    if (self) {
        document = nil;
        selector = [[NodeStyleSelector alloc] initWithStyleManager:m];
		editor = [[NodeStyleEditor alloc] init];

        palette = gtk_vbox_new (FALSE, 0);
		// FIXME: remove this line when we add edge styles
		gtk_container_set_border_width (GTK_CONTAINER (palette), 6);
		gtk_box_set_spacing (GTK_BOX (palette), 6);
		g_object_ref_sink (palette);

		gtk_box_pack_start (GTK_BOX (palette), [editor widget], FALSE, FALSE, 0);
		gtk_widget_show ([editor widget]);
		GtkWidget *selectorFrame = gtk_frame_new (NULL);
		gtk_container_add (GTK_CONTAINER (selectorFrame), [selector widget]);
		gtk_box_pack_start (GTK_BOX (palette), selectorFrame, TRUE, TRUE, 0);
		gtk_widget_show (selectorFrame);
		gtk_widget_show ([selector widget]);

        GtkBox *buttonBox = GTK_BOX (gtk_hbox_new(FALSE, 5));
		gtk_box_pack_start (GTK_BOX (palette), GTK_WIDGET (buttonBox), FALSE, FALSE, 0);

        GtkBox *bbox1 = GTK_BOX (gtk_hbox_new(FALSE, 0));
		gtk_box_pack_start (buttonBox, GTK_WIDGET (bbox1), FALSE, FALSE, 0);

        GtkWidget *addStyleButton = gtk_button_new ();
        gtk_widget_set_tooltip_text (addStyleButton, "Add a new style");
        GtkWidget *addIcon = gtk_image_new_from_stock (GTK_STOCK_ADD, GTK_ICON_SIZE_BUTTON);
        gtk_container_add (GTK_CONTAINER (addStyleButton), addIcon);
        gtk_box_pack_start (bbox1, addStyleButton, FALSE, FALSE, 0);
        g_signal_connect (G_OBJECT (addStyleButton),
            "clicked",
            G_CALLBACK (add_style_button_cb),
            self);

        removeStyleButton = gtk_button_new ();
		g_object_ref_sink (removeStyleButton);
        gtk_widget_set_tooltip_text (removeStyleButton, "Delete selected style");
        GtkWidget *removeIcon = gtk_image_new_from_stock (GTK_STOCK_REMOVE, GTK_ICON_SIZE_BUTTON);
        gtk_container_add (GTK_CONTAINER (removeStyleButton), removeIcon);
        gtk_box_pack_start (bbox1, removeStyleButton, FALSE, FALSE, 0);
        g_signal_connect (G_OBJECT (removeStyleButton),
            "clicked",
            G_CALLBACK (remove_style_button_cb),
            self);

        GtkBox *bbox2 = GTK_BOX (gtk_hbox_new(FALSE, 0));
		gtk_box_pack_start (buttonBox, GTK_WIDGET (bbox2), FALSE, FALSE, 0);

        applyStyleButton = gtk_button_new_with_label ("Apply");
		g_object_ref_sink (applyStyleButton);
        gtk_widget_set_tooltip_text (applyStyleButton, "Apply style to selected nodes");
        gtk_box_pack_start (bbox2, applyStyleButton, FALSE, FALSE, 5);
        g_signal_connect (G_OBJECT (applyStyleButton),
            "clicked",
            G_CALLBACK (apply_style_button_cb),
            self);

        clearStyleButton = gtk_button_new_with_label ("Clear");
		g_object_ref_sink (clearStyleButton);
        gtk_widget_set_tooltip_text (clearStyleButton, "Clear style from selected nodes");
        gtk_box_pack_start (bbox2, clearStyleButton, FALSE, FALSE, 0);
        g_signal_connect (G_OBJECT (clearStyleButton),
            "clicked",
            G_CALLBACK (clear_style_button_cb),
            self);

		gtk_widget_show_all (GTK_WIDGET (buttonBox));

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(selectedStyleChanged:)
                                                     name:@"SelectedStyleChanged"
                                                   object:selector];

		[self updateButtonState];
    }

    return self;
}

- (StyleManager*) styleManager {
    return [selector styleManager];
}

- (void) setStyleManager:(StyleManager*)m {
    [selector setStyleManager:m];
}

- (TikzDocument*) document {
    return document;
}

- (void) setDocument:(TikzDocument*)doc {
    if (document != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:nil
                                                      object:[document pickSupport]];
    }

    [doc retain];
    [document release];
    document = doc;

    if (document != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(nodeSelectionChanged:)
                                                     name:@"NodeSelectionChanged"
                                                   object:[document pickSupport]];
    }
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [editor release];
    [selector release];
    [document release];
	g_object_unref (palette);
	g_object_unref (removeStyleButton);
	g_object_unref (applyStyleButton);
	g_object_unref (clearStyleButton);

    [super dealloc];
}

@end

// }}}
// {{{ Notifications

@implementation NodeStylesPalette (Notifications)
- (void) selectedStyleChanged:(NSNotification*)notification {
	[editor setStyle:[selector selectedStyle]];
    [self updateButtonState];
}

- (void) nodeSelectionChanged:(NSNotification*)n {
    [self updateButtonState];
}
@end

// }}}
// {{{ Private

@implementation NodeStylesPalette (Private)
- (void) updateButtonState {
    gboolean hasNodeSelection = [[[document pickSupport] selectedNodes] count] > 0;
    gboolean hasStyleSelection = [selector selectedStyle] != nil;

    gtk_widget_set_sensitive (applyStyleButton, hasNodeSelection && hasStyleSelection);
    gtk_widget_set_sensitive (clearStyleButton, hasNodeSelection);
	gtk_widget_set_sensitive (removeStyleButton, hasStyleSelection);
}

- (void) removeSelectedStyle {
    NodeStyle *style = [selector selectedStyle];
    if (style)
        [[selector styleManager] removeNodeStyle:style];
}

- (void) applySelectedStyle {
    [document startModifyNodes:[[document pickSupport] selectedNodes]];

    NodeStyle *style = [selector selectedStyle];
    for (Node *node in [[document pickSupport] selectedNodes]) {
        [node setStyle:style];
    }

    [document endModifyNodes];
}

- (void) clearSelectedStyle {
    [document startModifyNodes:[[document pickSupport] selectedNodes]];

    for (Node *node in [[document pickSupport] selectedNodes]) {
        [node setStyle:nil];
    }

    [document endModifyNodes];
}

@end

// }}}
// {{{ GTK+ callbacks

static void add_style_button_cb (GtkButton *widget, NodeStylesPalette *palette) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NodeStyle *newStyle = [NodeStyle defaultNodeStyleWithName:@"newstyle"];
    [[palette styleManager] addNodeStyle:newStyle];
    [[palette styleManager] setActiveNodeStyle:newStyle];

    [pool drain];
}

static void remove_style_button_cb (GtkButton *widget, NodeStylesPalette *palette) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [palette removeSelectedStyle];
    [pool drain];
}

static void apply_style_button_cb (GtkButton *widget, NodeStylesPalette *palette) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [palette applySelectedStyle];
    [pool drain];
}

static void clear_style_button_cb (GtkButton *widget, NodeStylesPalette *palette) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [palette clearSelectedStyle];
    [pool drain];
}

// }}}

// vim:ft=objc:ts=4:noet:sts=4:sw=4:foldmethod=marker
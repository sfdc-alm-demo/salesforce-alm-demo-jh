/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */


/**
     @author        Paul Lucas
     @company       Salesforce
     @description   
     @date          30/11/2023

     TODO:
 */

trigger XDO_Tool_PlatformTrackingEvent on XDO_Tool_Platform_Tracking_Event__e (after insert) {
    new XDO_Tool_TrackingEventHandler().run();
}
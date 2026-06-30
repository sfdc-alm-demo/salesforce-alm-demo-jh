/**
 * BookingService — demo class for the salesforce-alm-demo walkthrough.
 *
 * Models a tiny travel-booking scenario: validate a booking request,
 * compute a price with optional rush-fee, and persist a Booking__c record.
 *
 * The demo intentionally introduces a coverage gap on Day 1 (the
 * applyRushFee path is not exercised by tests) so the matrix validation
 * job fails the coverage gate. We fix it live in front of the audience.
 */
public with sharing class BookingService {

    public class BookingException extends Exception {}

    public class BookingRequest {
        public String customerEmail;
        public Date travelDate;
        public Decimal basePrice;
        public Boolean rush;
    }

    /**
     * Compute the final price for a booking request.
     * Rush bookings (within 7 days of travel date) get a 25% surcharge.
     */
    public static Decimal computePrice(BookingRequest req) {
        if (req == null) {
            throw new BookingException('Booking request cannot be null');
        }
        if (req.basePrice == null || req.basePrice <= 0) {
            throw new BookingException('Base price must be positive');
        }
        if (req.rush == true) {
            return applyRushFee(req.basePrice);
        }
        return req.basePrice;
    }

    /**
     * Apply the 25% rush fee. Separate method so tests can target it
     * directly — but the v1 demo deliberately does NOT test this path
     * to demonstrate the coverage gate.
     */
    public static Decimal applyRushFee(Decimal basePrice) {
        return basePrice * 1.25;
    }

    private static final Decimal LOYALTY_RATE = 0.02;
    private static final Decimal LOYALTY_CAP = 0.20;

    /**
     * Apply a loyalty discount: 2% per year of tenure, capped at 20%.
     * No discount is applied for fewer than 1 year.
     *
     * @param basePrice The pre-discount price; must be positive
     * @param yearsAsCustomer Full years of tenure; null or 0 yields no discount
     * @return The discounted price
     */
    public static Decimal applyLoyaltyDiscount(Decimal basePrice, Integer yearsAsCustomer) {
        if (yearsAsCustomer == null || yearsAsCustomer < 1) {
            return basePrice;
        }
        Decimal rate = Math.min(yearsAsCustomer * LOYALTY_RATE, LOYALTY_CAP);
        return basePrice * (1 - rate);
    }

    /**
     * Validate that the email looks well-formed.
     */
    public static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        return Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', email);
    }
}

/// Lifecycle stage for an assigned delivery order (rider workflow).
enum OrderStage {
  /// Rider is en route to the restaurant.
  enRouteToRestaurant,

  /// Rider confirmed presence at the restaurant; next action is heading out.
  atRestaurant,

  /// Rider notified customer they are heading to the drop-off.
  headingToCustomer,

  /// Rider confirmed they are at the drop-off; next step is marking delivery.
  readyToMarkDelivered,

  /// UI shows delivery PIN entry from the customer.
  awaitingDeliveryCode,

  /// Order successfully completed.
  delivered,
}
